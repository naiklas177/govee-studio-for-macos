// Offline UI benchmark. Compile with MEDIA_EXPORT so StudioModel cannot load
// user state, capture a screen/audio stream, or start discovery on initialization.
import SwiftUI
import AppKit
import Darwin
import AmbienceCore

#if !MEDIA_EXPORT
#error("Compile this offline benchmark with -D MEDIA_EXPORT")
#endif

@main
struct BenchmarkUI {
    @MainActor static func snapshot(_ host: NSView,to path: String) throws {
        guard let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds) else { fatalError("bitmap allocation") }
        host.cacheDisplay(in:host.bounds,to:bitmap)
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
    }

    static func cpuSeconds() -> Double {
        var usage=rusage()
        getrusage(RUSAGE_SELF,&usage)
        return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1_000_000
    }

    @MainActor static func main() throws {
        _ = NSApplication.shared
        let mode=CommandLine.arguments.dropFirst().first ?? "hybrid"
        precondition(["idle","screen","audio","hybrid"].contains(mode))
        let model=StudioModel()
        model.show.mode = mode == "screen" ? .ambience:.music
        model.show.musicBackground.enabled = mode == "hybrid"
        model.show.musicPattern = .pulse
        model.show.musicColors = .fire
        model.runState = mode == "idle" ? .idle:.preview
        model.devices=zip(["H606A","H606A","H61A0","H61A2"],[10,10,18,30]).enumerated().map { i,pair in
            var device=DeviceConfig(id:"synthetic-\(i)",ip:"127.0.0.1",sku:pair.0)
            device.name="Demo light \(i+1)"
            device.zones=MappingPreset.grid.zones(count:pair.1)
            return device
        }
        model.notice="Offline synthetic UI benchmark — no hardware or capture"
        let host=NSHostingView(rootView:StudioView().environmentObject(model).environment(\.colorScheme,.dark))
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1440,height:980),styleMask:[.borderless],backing:.buffered,defer:false)
        window.contentView=host
        host.frame=NSRect(x:0,y:0,width:1440,height:980)
        // Never order the window onscreen: the user's active Ambilight keeps its input.
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until:Date().addingTimeInterval(0.5))
        if CommandLine.arguments.count > 2 {
            try snapshot(host,to:CommandLine.arguments[2]+".initial.png")
        }
        var start=0.0, cpuStart=0.0
        let warmup=10, measured=50
        for frame in 0..<(warmup+measured) {
            if frame == warmup { start=ProcessInfo.processInfo.systemUptime; cpuStart=cpuSeconds() }
            let deadline=Date().addingTimeInterval(0.2)
            if mode != "idle" {
                let t=Double(frame)*0.2
                let signal=AudioLevels(bass:0.08*(1+sin(t*4)),mid:0.04*(1+sin(t*7)),high:0.02*(1+sin(t*11)),level:0.08)
                var colors:[String:[RGB]]=[:]
                for (i,device) in model.devices.enumerated() {
                    colors[device.id]=ShowRenderer.colors(count:device.zones.count,time:t,offset:Double(i)*0.17,settings:model.show,audio:signal)
                }
                model.live.report=FrameReport(image:nil,colors:colors,fps:25,workMS:0.25,crop:SampleZone(x:0,y:0,width:1,height:1),audio:signal,audioReceiving:mode != "screen",backgroundFrames:mode == "hybrid" ? frame+1:0)
            }
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until:deadline)
            host.layoutSubtreeIfNeeded()
        }
        let seconds=ProcessInfo.processInfo.systemUptime-start, cpu=cpuSeconds()-cpuStart
        let metrics:[String:Any]=["mode":mode,"reports":mode == "idle" ? 0:measured,"wall_seconds":seconds,"cpu_seconds":cpu,"cpu_percent_one_core":100*cpu/seconds,"scope":"offscreen SwiftUI layout with synthetic 5 Hz telemetry; no capture, audio input or LAN"]
        print(String(data:try JSONSerialization.data(withJSONObject:metrics,options:[.sortedKeys]),encoding:.utf8)!)
        if CommandLine.arguments.count > 2 {
            try snapshot(host,to:CommandLine.arguments[2])
        }
        withExtendedLifetime(window) {}
    }
}
