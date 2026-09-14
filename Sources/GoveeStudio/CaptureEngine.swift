import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import AVFoundation
import AmbienceCore

struct FrameReport {
    var image: CGImage?
    var colors: [String:[RGB]]
    var fps: Double
    var workMS: Double
    var crop: SampleZone
    var audio: AudioLevels = .silent
    var audioReceiving: Bool = false
    var backgroundFrames: Int = 0
}

/// Capture, sampling and network output stay away from the UI thread.
/// Only a small 5 Hz preview is copied for SwiftUI; full frames never hit disk.
final class CaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue=DispatchQueue(label:"studio.govee.capture",qos:.userInitiated)
    private var stream: SCStream?
    private var showTimer: DispatchSourceTimer?
    private var show=ShowSettings()
    private var mode: ExperienceMode = .ambience
    private var analyzer=AudioAnalyzer()
    private var bassWave=BassWaveTracker()
    private var musicBeat=MusicBeatTracker()
    private var audio=AudioLevels.silent
    private var lastAudio=0.0
    private var keepalive: DispatchSourceTimer?
    private var sessionRoutes: [String:DeviceConfig]=[:]
    private let transport: LANTransport
    private var devices: [DeviceConfig]=[]
    private var settings=StudioSettings()
    private var output=false
    private var active=false
    private var backgroundFrames=0
    private var screenSamples: [String:[RGB]]=[:]
    private var screenPrevious: [String:[RGB]]=[:]
    private var previous: [String:[RGB]]=[:]
    private var lastSent: [String:([RGB],Double)]=[:]
    private var lastFrame=0.0
    private var lastReport=0.0
    private var frames=0
    private var workTotal=0.0
    private var startedAt=0.0
    private var crop=SampleZone(x:0,y:0,width:1,height:1)
    private var cropCheck=0.0
    private var errorReported=false
    var onFrame: ((FrameReport)->Void)?
    var onFailure: ((String)->Void)?
    init(transport: LANTransport) { self.transport=transport }
    func update(devices: [DeviceConfig], settings: StudioSettings) {
        queue.async {
            self.devices = self.output ? devices.compactMap { candidate in
                guard let route=self.sessionRoutes[candidate.id] else { return nil }
                var d=candidate; d.ip=route.ip; d.mode=route.mode; d.header=route.header; d.stretch=route.stretch
                return d
            } : devices
            self.settings=settings
        }
    }
    func updateShow(_ settings: ShowSettings) { queue.async { self.show=settings } }
    func updateZone(_ zone: SampleZone, index: Int, deviceID: String) {
        queue.async {
            guard let i=self.devices.firstIndex(where:{$0.id == deviceID}), self.devices[i].zones.indices.contains(index) else { return }
            self.devices[i].zones[index]=zone
        }
    }
    func start(display: SCDisplay?, devices: [DeviceConfig], settings: StudioSettings, output: Bool, show: ShowSettings) async throws {
        queue.sync {
            self.devices=devices; self.settings=settings; self.output=output; self.show=show; self.mode=show.mode
            self.sessionRoutes=Dictionary(uniqueKeysWithValues:devices.map { ($0.id,$0) })
            previous=[:]; screenSamples=[:]; screenPrevious=[:]; lastSent=[:]; lastFrame=0; lastReport=0; frames=0; workTotal=0
            analyzer=AudioAnalyzer(); bassWave=BassWaveTracker(); musicBeat=MusicBeatTracker(); audio = .silent; lastAudio=0; backgroundFrames=0
            cropCheck=0; crop=SampleZone(x:0,y:0,width:1,height:1)
            startedAt=ProcessInfo.processInfo.systemUptime; active=true; errorReported=false
        }
        if show.mode == .scenes { startShowTimer(); return }
        guard let display else { throw StudioError.message("Der gewählte Bildschirm ist nicht verfügbar.") }
        let apps=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true).applications
        let ours=apps.filter { $0.processID == getpid() }
        let filter=SCContentFilter(display:display,excludingApplications:ours,exceptingWindows:[])
        let config=SCStreamConfiguration()
        let hybrid=show.mode == .music && show.musicBackground.enabled
        config.width=show.mode == .music && !hybrid ? 16:384
        config.height=show.mode == .music && !hybrid ? 16:max(64,Int(384*Double(display.height)/Double(display.width)))
        config.minimumFrameInterval=CMTime(value:1,timescale:CMTimeScale(settings.fps))
        config.queueDepth=3
        config.pixelFormat=kCVPixelFormatType_32BGRA
        config.colorSpaceName=CGColorSpace.sRGB
        config.showsCursor=false
        config.capturesAudio=show.mode == .music
        config.sampleRate=48000; config.channelCount=2; config.excludesCurrentProcessAudio=true
        config.scalesToFit=true
        let session=SCStream(filter:filter,configuration:config,delegate:self)
        if show.mode == .music {
            try session.addStreamOutput(self,type:.audio,sampleHandlerQueue:queue)
            if hybrid { try session.addStreamOutput(self,type:.screen,sampleHandlerQueue:queue) }
        } else { try session.addStreamOutput(self,type:.screen,sampleHandlerQueue:queue) }
        stream=session
        let timer=DispatchSource.makeTimerSource(queue:queue)
        timer.schedule(deadline:.now()+1,repeating:1)
        timer.setEventHandler { [weak self] in self?.sendKeepalive() }
        keepalive=timer; timer.resume()
        do { try await session.startCapture(); if show.mode == .music { startShowTimer() } }
        catch { queue.sync { active=false }; keepalive?.cancel(); keepalive=nil; stream=nil; throw error }
    }
    func stop() async {
        // Barrier guarantees no further color frames can follow the restore commands.
        queue.sync { active=false; output=false; keepalive?.cancel(); keepalive=nil; showTimer?.cancel(); showTimer=nil }
        let old=stream; stream=nil
        try? await old?.stopCapture()
    }
    private func startShowTimer() {
        queue.sync {
            let timer=DispatchSource.makeTimerSource(queue:queue)
            timer.schedule(deadline:.now(),repeating:1.0/Double(settings.fps),leeway:.milliseconds(2))
            timer.setEventHandler { [weak self] in self?.renderShow() }
            showTimer=timer; timer.resume()
        }
    }
    private func processAudio(_ buffer: CMSampleBuffer) {
        try? buffer.withAudioBufferList { list, _ in
            guard let description=buffer.formatDescription?.audioStreamBasicDescription,
                  description.mFormatID == kAudioFormatLinearPCM,
                  description.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  description.mBitsPerChannel == 32 else { return }
            let buffers=UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating:list.unsafePointer))
            guard let first=buffers.first,let data=first.mData else { return }
            let channels=max(1,Int(first.mNumberChannels))
            let length=Int(first.mDataByteSize)/MemoryLayout<Float>.size/channels
            let samples=data.assumingMemoryBound(to:Float.self)
            var mono=[Float](repeating:0,count:length)
            for frame in 0..<length {
                if buffers.count == 1 {
                    for channel in 0..<channels { mono[frame] += samples[frame*channels+channel]/Float(channels) }
                } else {
                    for plane in buffers {
                        if let pointer=plane.mData, frame*4 < Int(plane.mDataByteSize) {
                            mono[frame] += pointer.assumingMemoryBound(to:Float.self)[frame]/Float(buffers.count)
                        }
                    }
                }
            }
            audio=analyzer.process(mono,sampleRate:description.mSampleRate)
            lastAudio=ProcessInfo.processInfo.systemUptime
        }
    }
    private func renderShow() {
        guard active else { return }
        let now=ProcessInfo.processInfo.systemUptime
        let delta=lastFrame > 0 ? now-lastFrame:1/Double(settings.fps); lastFrame=now
        let receiving=lastAudio > 0 && now-lastAudio < 0.35
        let signal=receiving ? audio:.silent
        let beat=musicBeat.update(audio:signal,time:now,sensitivity:show.sensitivity)
        let wave=bassWave.update(bass:signal.bass*show.sensitivity,time:now)
        var colors: [String:[RGB]]=[:]
        for (index,device) in devices.enumerated() where device.enabled {
            var effectSettings=show
            if mode == .music { effectSettings.background=0 }
            let generated=ShowRenderer.colors(count:show.count(for:device),time:now-startedAt,offset:Double(index)*0.17,settings:effectSettings,audio:signal,waveAge:wave?.age,waveStrength:wave?.strength ?? 0,beat:beat)
            let effects=generated.enumerated().map { i,color -> RGB in
                let target=mode == .music ? color.adjusted(gain:1,saturation:show.musicSaturation,blackThreshold:0):color
                guard let old=previous[device.id],old.count == generated.count else { return target }
                let rising=target.r+target.g+target.b > old[i].r+old[i].g+old[i].b
                let tau=mode == .music ? (rising ? 0.035:show.decay):max(0.08,settings.smoothing)
                return old[i].mixed(with:target,amount:ColorSampler.smoothingAlpha(delta:delta,timeConstant:tau))
            }
            previous[device.id]=effects
            let ambient=show.musicBackground
            let samples=screenSamples[device.id] ?? []
            let backgrounds=effects.indices.map { i -> RGB in
                guard mode == .music else { return .black }
                if !ambient.enabled { return ShowRenderer.hue(show.backgroundHue).adjusted(gain:show.background,saturation:0.65,blackThreshold:0) }
                let raw=samples.isEmpty ? RGB.black:samples[min(samples.count-1,i*samples.count/effects.count)]
                let target=raw.adjusted(gain:ambient.gain,saturation:ambient.saturation,blackThreshold:0)
                guard let old=screenPrevious[device.id],old.count == effects.count else { return target }
                return old[i].mixed(with:target,amount:ColorSampler.smoothingAlpha(delta:delta,timeConstant:ambient.smoothing))
            }
            screenPrevious[device.id]=backgrounds
            let values=effects.enumerated().map { i,effect -> RGB in
                let mixed=mode == .music ? ShowRenderer.composite(background:backgrounds[i],effect:effect):effect
                // Music and background saturation are independent in hybrid mode.
                return mixed.adjusted(gain:device.gain*settings.masterGain,saturation:mode == .music ? 1:settings.saturation,blackThreshold:0)
            }
            colors[device.id]=values
            let ordered=device.reverse ? Array(values.reversed()):values
            if output {
                let old=lastSent[device.id], elapsed=now-(lastSent[device.id]?.1 ?? 0)
                if (old?.0.map(\.bytes) != ordered.map(\.bytes) || elapsed >= 1) && (device.mode == .dreamview || elapsed >= 0.1) {
                    do {
                        let packet=device.mode == .dreamview ? try GoveeProtocol.frame(ordered,header:device.header,stretch:device.stretch):GoveeProtocol.color(ordered[0])
                        try transport.send(packet,to:device.ip); lastSent[device.id]=(ordered,now)
                    } catch {
                        output=false
                        if !errorReported { errorReported=true; onFailure?(error.localizedDescription) }
                    }
                }
            }
        }
        workTotal += (ProcessInfo.processInfo.systemUptime-now)*1000; frames += 1
        if now-lastReport >= 0.1 {
            onFrame?(FrameReport(image:nil,colors:colors,fps:Double(frames)/max(0.001,now-startedAt),workMS:workTotal/Double(frames),crop:crop,audio:signal,audioReceiving:receiving,backgroundFrames:backgroundFrames))
            lastReport=now
        }
    }
    private func sendKeepalive() {
        guard active,output else { return }
        let now=ProcessInfo.processInfo.systemUptime
        for device in devices where device.enabled {
            guard let last=lastSent[device.id], now-last.1 >= 0.9 else { continue }
            do {
                let packet=device.mode == .dreamview ? try GoveeProtocol.frame(last.0,header:device.header,stretch:device.stretch) : GoveeProtocol.color(last.0[0])
                try transport.send(packet,to:device.ip)
                lastSent[device.id]=(last.0,now)
            } catch {
                output=false
                if !errorReported { errorReported=true; onFailure?(error.localizedDescription) }
            }
        }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        queue.async {
            guard self.active else { return }
            self.active=false
            self.onFailure?(error.localizedDescription)
        }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if active, type == .audio, sampleBuffer.isValid { processAudio(sampleBuffer); return }
        guard active, (mode == .ambience || (mode == .music && show.musicBackground.enabled)), type == .screen, sampleBuffer.isValid,
              let attachments=CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],
              let raw=attachments.first?[.status] as? Int, SCFrameStatus(rawValue:raw) == .complete,
              let pixel=CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now=ProcessInfo.processInfo.systemUptime
        let delta=lastFrame > 0 ? min(1,now-lastFrame) : 1/Double(settings.fps)
        if mode == .ambience { lastFrame=now }
        CVPixelBufferLockBaseAddress(pixel,.readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixel,.readOnly) }
        guard let base=CVPixelBufferGetBaseAddress(pixel)?.assumingMemoryBound(to:UInt8.self) else { return }
        let width=CVPixelBufferGetWidth(pixel), height=CVPixelBufferGetHeight(pixel), stride=CVPixelBufferGetBytesPerRow(pixel)
        if now-cropCheck > 0.5 {
            crop=(mode == .music ? show.musicBackground.cropBars:settings.cropBars) ? ColorSampler.activePicture(bytes:base,width:width,height:height,stride:stride) : SampleZone(x:0,y:0,width:1,height:1)
            cropCheck=now
        }
        if mode == .music {
            for device in devices where device.enabled {
                let zones=device.mode == .whole ? Array(device.zones.prefix(1)):device.zones
                screenSamples[device.id]=zones.map { ColorSampler.average(bytes:base,width:width,height:height,stride:stride,zone:$0,crop:crop) }
            }
            backgroundFrames += 1
            return // Only the show timer combines layers and sends light frames.
        }
        var colors: [String:[RGB]]=[:]
        let alpha=ColorSampler.smoothingAlpha(delta:delta,timeConstant:settings.smoothing)
        for device in devices where device.enabled {
            let zones=device.mode == .whole ? [device.zones.first ?? SampleZone(x:0,y:0,width:1,height:1)] : device.zones
            let values=zones.enumerated().map { index,zone -> RGB in
                let sample=ColorSampler.average(bytes:base,width:width,height:height,stride:stride,zone:zone,crop:crop)
                    .adjusted(gain:device.gain*settings.masterGain,saturation:settings.saturation,blackThreshold:settings.blackThreshold)
                if let old=previous[device.id], old.count == zones.count { return old[index].mixed(with:sample,amount:alpha) }
                return sample
            }
            previous[device.id]=values
            colors[device.id]=values
            let ordered=device.reverse ? Array(values.reversed()) : values
            if output {
                let old=lastSent[device.id]
                // Keepalive once a second. Whole-device mode is capped at 10 Hz.
                let changed=old?.0.map(\.bytes) != ordered.map(\.bytes)
                let elapsed=now-(old?.1 ?? 0)
                if (changed || elapsed >= 1) && (device.mode == .dreamview || elapsed >= 0.1) {
                    do {
                        let data=device.mode == .dreamview ? try GoveeProtocol.frame(ordered,header:device.header,stretch:device.stretch) : GoveeProtocol.color(ordered[0])
                        try transport.send(data,to:device.ip)
                        lastSent[device.id]=(ordered,now)
                    } catch {
                        output=false
                        if !errorReported { errorReported=true; onFailure?(error.localizedDescription) }
                    }
                }
            }
        }
        let elapsed=(ProcessInfo.processInfo.systemUptime-now)*1000
        workTotal += elapsed; frames += 1
        if now-lastReport >= 0.2 {
            let data=Data(bytes:base,count:stride*height)
            let provider=CGDataProvider(data:data as CFData)
            let image=provider.flatMap { CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:stride,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),provider:$0,decode:nil,shouldInterpolate:true,intent:.defaultIntent) }
            onFrame?(FrameReport(image:image,colors:colors,fps:Double(frames)/max(0.001,now-startedAt),workMS:workTotal/Double(frames),crop:crop))
            lastReport=now
        }
    }
}
