import AppKit
import SwiftUI
import ScreenCaptureKit
import AmbienceCore

struct DisplayChoice: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let width: Int
    let height: Int
}
enum RunState { case idle, starting, preview, syncing, stopping }

@MainActor
final class LiveTelemetry: ObservableObject {
    @Published var report=FrameReport(image:nil,colors:[:],fps:0,workMS:0,crop:SampleZone(x:0,y:0,width:1,height:1))
    var frame: CGImage? { report.image }
    var colors: [String:[RGB]] { report.colors }
    var fps: Double { report.fps }
    var workMS: Double { report.workMS }
    var crop: SampleZone { report.crop }
    func clear() { report=FrameReport(image:nil,colors:[:],fps:0,workMS:0,crop:SampleZone(x:0,y:0,width:1,height:1)) }
}

@MainActor
final class StudioModel: ObservableObject {
    @Published var show=ShowSettings()
    @Published var setupTab=false
    @Published var browseCloud=false
    @Published var nativeMusic=false
    @Published var activeCloud: CloudScene?
    @Published var activeRoom: RoomOutputPlan?
    @Published var roomApplying=false
    private var roomControlsTask: Task<Void,Never>?
    lazy var cloud=CloudLibrary(directory:directory)
    @Published var switchingMode=false
    @Published var requestedMode: ExperienceMode?
    @Published var probeChannel=0
    @Published var channelProbe=false
    @Published var devices: [DeviceConfig]=[]
    @Published var selectedID: String?
    @Published var selectedZone=0
    @Published var settings=StudioSettings()
    @Published var profiles: [StudioProfile]=[]
    @Published var displays: [DisplayChoice]=[]
    @Published var displayID: CGDirectDisplayID=CGMainDisplayID()
    @Published var lastSeen: [String:Date]=[:]
    @Published var states: [String:LightState]=[:]
    @Published var runState=RunState.idle
    @Published var scanning=false
    @Published var message: String?
    @Published var notice="Bereit für dein Licht."
    @Published var bandwidth=0.0
    @Published var profileName="Mein Setup"
    @Published var recoveryAvailable=false
    @Published var testActive=false
    private var stopTask: Task<Void,Never>?
    private var startupTask: Task<Void,Never>?
    private var identifyTask: Task<Void,Never>?
    private var maintenance: Timer?
    private var saves: Task<Void,Never>?
    private var recovery: [RecoveryLight]=[]
    private var networkReady=false
    private var lastBytes=0
    private var lastCounterTime=Date()
    let live=LiveTelemetry()
    let transport=LANTransport()
    lazy var engine=CaptureEngine(transport:transport)
    let directory: URL
    var running: Bool { (activeCloud == nil || !(activeRoom?.ambilightIDs.isEmpty ?? true)) && (runState == .syncing || runState == .preview) }
    lazy var modeActivation: ModeActivationQueue<OutputTarget> = {
        let queue=ModeActivationQueue<OutputTarget>()
        queue.changed={ [weak self] active,target in self?.switchingMode=active; self?.requestedMode=target?.mode }
        queue.interruptStart={ [weak self] in self?.startupTask?.cancel() }
        queue.stopCurrent={ [weak self] in await self?.stopSession() }
        queue.start={ [weak self] target in
            guard let self else { return }
            self.show.mode=target.mode; self.showChanged()
            self.runState = .starting
            let task=Task {
                switch target {
                case .local: self.browseCloud=false; self.nativeMusic=false; await self.start(output:true)
                case .cloud(let scene): self.browseCloud=scene.kind != "musicMode"; self.nativeMusic=scene.kind == "musicMode"; await self.startCloud(scene)
                case .roomScenes(let plan): self.browseCloud=true; self.nativeMusic=false; await self.startRoom(plan)
                case .room(let plan): self.browseCloud=false; self.nativeMusic=true; await self.startRoom(plan)
                }
            }
            self.startupTask=task
            await task.value
        }
        return queue
    }()
    func activateMode(_ mode: ExperienceMode) {
        setupTab=false; browseCloud=false; nativeMusic=false
        if activeCloud == nil && show.mode == mode && runState == .syncing && !switchingMode { return }
        modeActivation.request(.local(mode))
    }
    var busy: Bool { runState != .idle || testActive || switchingMode }
    var selected: DeviceConfig? { devices.first { $0.id == selectedID } }
    var onlineCount: Int { devices.filter { isOnline($0) }.count }
    var segmentCount: Int { devices.filter(\.enabled).reduce(0) { $0+($1.mode == .whole ? 1 : $1.zones.count) } }
    var aspect: Double { if let display=displays.first(where:{$0.id == displayID}) { return Double(display.width)/Double(display.height) }; return 16/9 }

    init() {
        directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("GoveeStudio",isDirectory:true)
        do { try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true) } catch { message=error.localizedDescription }
        load()
        if let data=try? Data(contentsOf:directory.appendingPathComponent("show.json")),let saved=try? JSONDecoder().decode(ShowSettings.self,from:data) { show=saved; show.validate() }
        recoveryAvailable=FileManager.default.fileExists(atPath:directory.appendingPathComponent("recovery.json").path)
        displays=NSScreen.screens.compactMap { screen in
            guard let id=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
            return DisplayChoice(id:id,name:screen.localizedName,width:CGDisplayPixelsWide(id),height:CGDisplayPixelsHigh(id))
        }
        transport.onDevice={ [weak self] announcement in Task { @MainActor in self?.discovered(announcement) } }
        transport.onState={ [weak self] ip,state in Task { @MainActor in
            guard let self else { return }
            self.states[ip]=state
            if let d=self.devices.first(where:{$0.ip == ip}) { self.lastSeen[d.id]=Date() }
        } }
        engine.onFrame={ [weak self] report in Task { @MainActor in
            guard let self, self.running else { return }
            self.live.report=report
        } }
        engine.onFailure={ [weak self] error in Task { @MainActor in
            guard let self else { return }
            self.message="Bildschirm-Sync beendet: \(error)"
            await self.stop()
        } }
        maintenance=Timer.scheduledTimer(withTimeInterval:10,repeats:true) { [weak self] _ in Task { @MainActor in self?.maintain() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in await self?.stop() } }
        NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in
            guard let self else { return }; await self.stop()
            self.displays=NSScreen.screens.compactMap { screen in
                guard let id=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
                return DisplayChoice(id:id,name:screen.localizedName,width:CGDisplayPixelsWide(id),height:CGDisplayPixelsHigh(id))
            }
            if !self.displays.contains(where:{$0.id == self.displayID}) { self.displayID=CGMainDisplayID() }
        } }
        Task { await scan() }
    }
    func isOnline(_ device: DeviceConfig) -> Bool { Date().timeIntervalSince(lastSeen[device.id] ?? .distantPast) < 35 }
    private func ensureNetwork() throws { if !networkReady { try transport.open(); networkReady=true } }
    func scan() async {
        guard !scanning else { return }
        scanning=true
        defer { scanning=false }
        do {
            try ensureNetwork()
            var discoverySucceeded=false
            for _ in 0..<3 {
                // Multicast can be unavailable while direct LAN control still works.
                // Probe saved devices too; discovery failure must not block the editor.
                for device in devices { try? transport.query(ip:device.ip) }
                do { try transport.discover(); discoverySucceeded=true } catch { }
                try await Task.sleep(nanoseconds:900_000_000)
            }
            if !running && runState != .starting {
                notice=discoverySucceeded ? "\(onlineCount) Geräte im lokalen Netzwerk.":"Gerätesuche per Multicast nicht erreichbar · bekannte Leuchten werden direkt geprüft."
            }
        } catch { message=error.localizedDescription }
    }
    private func discovered(_ announcement: DeviceAnnouncement) {
        lastSeen[announcement.id]=Date()
        if let i=devices.firstIndex(where:{$0.id == announcement.id}) {
            if devices[i].ip != announcement.ip { devices[i].ip=announcement.ip; changed() }
        } else {
            let ordinal=devices.filter{$0.sku == announcement.sku}.count
            devices.append(DeviceConfig(id:announcement.id,ip:announcement.ip,sku:announcement.sku,ordinal:ordinal))
            devices.sort { $0.name < $1.name }
            if selectedID == nil { selectedID=devices.first?.id }
            changed()
        }
        try? transport.query(ip:announcement.ip)
    }
    private func maintain() {
        guard networkReady else { return }
        for device in devices { try? transport.query(ip:device.ip) }
        let (_,bytes)=transport.counters()
        bandwidth=Double(bytes-lastBytes)/max(1,Date().timeIntervalSince(lastCounterTime))/1024
        lastBytes=bytes; lastCounterTime=Date()
    }
    func select(_ id: String) { selectedID=id; selectedZone=0 }
    func editSelected(_ body: (inout DeviceConfig)->Void) {
        guard let index=devices.firstIndex(where:{$0.id == selectedID}) else { return }
        body(&devices[index]); devices[index].validate()
        selectedZone=devices[index].mode == .whole ? 0 : min(selectedZone,devices[index].zones.count-1)
        changed()
    }
    func setZone(_ zone: SampleZone, index: Int) {
        editSelected { d in guard d.zones.indices.contains(index) else { return }; d.zones[index]=zone }
    }
    func previewZone(_ zone: SampleZone, index: Int, deviceID: String) {
        engine.updateZone(zone,index:index,deviceID:deviceID)
    }
    func commitZone(_ zone: SampleZone, index: Int, deviceID: String) {
        guard let i=devices.firstIndex(where:{$0.id == deviceID}), devices[i].zones.indices.contains(index) else { return }
        var clamped=zone; clamped.clamp()
        guard devices[i].zones[index] != clamped else { return }
        devices[i].zones[index]=clamped
        changed()
    }
    func commitZones(_ changes: [Int:SampleZone], deviceID: String) {
        guard let i=devices.firstIndex(where:{$0.id == deviceID}) else { return }
        var device=devices[i]
        for (index,zone) in changes where device.zones.indices.contains(index) {
            var clamped=zone; clamped.clamp(); device.zones[index]=clamped
        }
        devices[i]=device
        changed()
    }
    func map(_ preset: MappingPreset) { editSelected { $0.zones=preset.zones(count:$0.zones.count) } }
    func setCount(_ count: Int) { editSelected { $0.zones=MappingPreset.grid.zones(count:count); $0.calibrated=false } }
    func showChanged() {
        show.validate(); engine.updateShow(show)
        if let data=try? JSONEncoder().encode(show) {
            do { try data.write(to:directory.appendingPathComponent("show.json"),options:.atomic) }
            catch { message="Show-Einstellungen konnten nicht gespeichert werden: \(error.localizedDescription)" }
        }
    }
    func chooseScene(_ scene: LightScene) {
        show.scene=scene; showChanged()
        if activeCloud != nil || switchingMode { modeActivation.request(.local(.scenes)) }
    }
    func changed() {
        settings.validate()
        var captureSettings=settings
        if let room=activeRoom,!room.ambilightIDs.isEmpty { captureSettings=room.screenSettings(base:settings) }
        engine.update(devices:devices,settings:captureSettings)
        saves?.cancel()
        saves=Task { try? await Task.sleep(nanoseconds:350_000_000); if !Task.isCancelled { save() } }
    }
    func save() {
        do {
            let saved=SavedWorkspace(devices:devices,settings:settings,profiles:profiles)
            let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
            try encoder.encode(saved).write(to:directory.appendingPathComponent("workspace.json"),options:.atomic)
        } catch { message="Setup konnte nicht gespeichert werden: \(error.localizedDescription)" }
    }
    private func load() {
        let file=directory.appendingPathComponent("workspace.json")
        guard FileManager.default.fileExists(atPath:file.path) else { return }
        do {
            let data=try Data(contentsOf:file)
            let saved=try JSONDecoder().decode(SavedWorkspace.self,from:data)
            guard saved.version == 1 else { throw StudioError.message("Unbekanntes Profilformat.") }
            devices=saved.devices; settings=saved.settings; profiles=saved.profiles
            for i in devices.indices { devices[i].validate(); if !devices[i].calibrated && devices[i].header == .dream { devices[i].header = .automatic } }
            settings.validate(); selectedID=devices.first?.id
        } catch { message="Gespeichertes Setup konnte nicht gelesen werden: \(error.localizedDescription)" }
    }
    func saveProfile() {
        let name=profileName.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let i=profiles.firstIndex(where:{$0.name == name}) { profiles[i]=StudioProfile(name:name,devices:devices,settings:settings) }
        else { profiles.append(StudioProfile(name:name,devices:devices,settings:settings)) }
        save(); notice="Profil „\(name)“ gespeichert."
    }
    func loadProfile(_ profile: StudioProfile) {
        guard !busy else { return }
        // Current discovery owns addresses; profiles only own layout and preferences.
        let current=devices
        devices=profile.devices.map { saved in
            var d=saved
            if let live=current.first(where:{$0.id == d.id}) { d.ip=live.ip }
            d.validate(); return d
        }
        devices += current.filter { live in !devices.contains(where:{$0.id == live.id}) }
        settings=profile.settings; settings.validate(); profileName=profile.name
        selectedID=devices.first?.id; selectedZone=0; changed()
    }
    func begin(output: Bool) {
        guard !busy else { return }
        runState = .starting
        startupTask=Task { await start(output:output) }
    }
    private func start(output: Bool) async {
        runState = .starting; message=nil
        do {
            if output && recoveryAvailable {
                notice="Vorherige Lichtwerte werden wiederhergestellt …"
                try ensureNetwork()
                recovery=try JSONDecoder().decode([RecoveryLight].self,from:Data(contentsOf:directory.appendingPathComponent("recovery.json")))
                await restoreUncancelled()
                guard !recoveryAvailable else {
                    throw StudioError.message("Eine Leuchte bestätigt die Wiederherstellung noch nicht. Prüfe ihre Verbindung und starte den Sync erneut; die App versucht es automatisch noch einmal.")
                }
                try Task.checkCancellation()
            }
            if show.mode != .scenes && !CGPreflightScreenCaptureAccess() {
                CGRequestScreenCaptureAccess()
                guard CGPreflightScreenCaptureAccess() else {
                    throw StudioError.message("Erlaube Govee Studio unter Systemeinstellungen → Datenschutz & Sicherheit → Bildschirmaufnahme. Danach die App gegebenenfalls neu öffnen.")
                }
            }
            var display: SCDisplay?
            if show.mode != .scenes {
                let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
                display=content.displays.first(where:{$0.displayID == displayID})
                guard display != nil else { throw StudioError.message("Der gewählte Bildschirm ist nicht verfügbar.") }
            }
            try Task.checkCancellation()
            let activeDevices=devices.filter(\.enabled)
            if output {
                guard !activeDevices.isEmpty else { throw StudioError.message("Wähle mindestens eine Leuchte aus.") }
                try ensureNetwork()
                // All snapshots must exist before any light is changed.
                var snapshots: [RecoveryLight]=[]
                for device in activeDevices {
                    let state=try await transport.snapshot(ip:device.ip)
                    snapshots.append(RecoveryLight(ip:device.ip,mode:device.mode,state:state))
                }
                try Task.checkCancellation()
                recovery=snapshots
                try JSONEncoder().encode(snapshots).write(to:directory.appendingPathComponent("recovery.json"),options:.atomic)
                for device in activeDevices {
                    try transport.send(GoveeProtocol.power(true),to:device.ip)
                    try await Task.sleep(nanoseconds:100_000_000)
                    try transport.send(GoveeProtocol.brightness(100),to:device.ip)
                    try await Task.sleep(nanoseconds:100_000_000)
                    if device.mode == .dreamview { try transport.send(GoveeProtocol.streamEnabled(true),to:device.ip) }
                    try await Task.sleep(nanoseconds:100_000_000)
                }
            }
            try Task.checkCancellation()
            try await engine.start(display:display,devices:devices,settings:settings,output:output,show:show)
            try Task.checkCancellation()
            runState=output ? .syncing:.preview
            notice=output ? "\(show.mode.rawValue) aktiv · Farben werden lokal gesendet." : "Vorschau · Leuchten bleiben unverändert."
            save()
        } catch {
            if !(error is CancellationError) { message=error.localizedDescription }
            await engine.stop()
            await restoreUncancelled()
            runState = .idle
        }
        startupTask=nil
    }
    func activateCloud(_ scene: CloudScene) {
        guard !cloud.key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { message="Bitte einen Govee-API-Key eingeben oder aus dem Schlüsselbund laden."; return }
        guard devices.contains(where:{$0.id == scene.device && $0.sku == scene.sku && $0.enabled}) else { message="Dieses Gerät zuerst im Setup aktivieren."; return }
        setupTab=false
        modeActivation.request(.cloud(scene))
    }
    func activateRoomScenes(_ selection: RoomSceneSelection) {
        guard !cloud.key.isEmpty else { message="Bitte Govee-API-Key eingeben."; return }
        do {
            let plan=try selection.plan(devices:devices,catalog:cloud.catalog)
            setupTab=false
            modeActivation.request(.roomScenes(plan))
        } catch { message=error.localizedDescription }
    }
    func activateRoom() {
        guard !cloud.key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { message="Bitte einen Govee-API-Key eingeben oder aus dem Schlüsselbund laden."; return }
        do {
            let plan=try cloud.room.plan(devices:devices,profiles:cloud.musicProfiles)
            cloud.saveRoom(); setupTab=false
            modeActivation.request(.room(plan))
        } catch { message=error.localizedDescription }
    }
    private func startCloud(_ scene: CloudScene) async {
        await startRoom(RoomOutputPlan(commands:[scene],ambilightIDs:[],ambientGain:0))
    }
    private func startRoom(_ plan: RoomOutputPlan) async {
        runState = .starting; message=nil
        do {
            try plan.validate(devices:devices)
            try ensureNetwork()
            if recoveryAvailable {
                recovery=try JSONDecoder().decode([RecoveryLight].self,from:Data(contentsOf:directory.appendingPathComponent("recovery.json")))
                await restoreUncancelled()
                guard !recoveryAvailable else { throw StudioError.message("Vorherige Lichtwerte konnten noch nicht wiederhergestellt werden.") }
            }
            var display: SCDisplay?
            if !plan.ambilightIDs.isEmpty {
                guard CGPreflightScreenCaptureAccess() else { throw StudioError.message("Für Ambilight bitte Bildschirmaufnahme erlauben.") }
                let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
                display=content.displays.first(where:{$0.displayID == displayID})
                guard display != nil else { throw StudioError.message("Gewählter Bildschirm nicht verfügbar.") }
            }
            try Task.checkCancellation()
            let targets=devices.filter { plan.ids.contains($0.id) }
            let screenDevices=targets.filter { plan.ambilightIDs.contains($0.id) }
            var snapshots:[RecoveryLight]=[]
            for device in targets {
                let snapshot=try await transport.snapshot(ip:device.ip)
                snapshots.append(RecoveryLight(ip:device.ip,mode:.dreamview,state:snapshot))
                try Task.checkCancellation()
            }
            recovery=snapshots
            try JSONEncoder().encode(recovery).write(to:directory.appendingPathComponent("recovery.json"),options:.atomic)
            recoveryAvailable=true
            let credential=cloud.key
            for device in targets {
                try Task.checkCancellation()
                try transport.send(GoveeProtocol.streamEnabled(false),to:device.ip)
                try await Task.sleep(nanoseconds:150_000_000)
                try transport.send(GoveeProtocol.power(true),to:device.ip)
                try await Task.sleep(nanoseconds:150_000_000)
                if let command=plan.commands.first(where:{$0.device == device.id}) {
                    // In-flight cloud writes settle before cancellation can restore the room.
                    let send=Task { try await self.cloud.api.activate(command,key:credential) }
                    try await send.value
                    try Task.checkCancellation()
                    if let brightness=plan.musicBrightness { try transport.send(GoveeProtocol.brightness(brightness),to:device.ip) }
                } else {
                    try transport.send(GoveeProtocol.brightness(100),to:device.ip)
                    try await Task.sleep(nanoseconds:100_000_000)
                    if device.mode == .dreamview { try transport.send(GoveeProtocol.streamEnabled(true),to:device.ip) }
                }
            }
            try Task.checkCancellation()
            if !screenDevices.isEmpty {
                var screenShow=show; screenShow.mode = .ambience
                let screenSettings=plan.screenSettings(base:settings)
                try await engine.start(display:display,devices:screenDevices,settings:screenSettings,output:true,show:screenShow)
                try Task.checkCancellation()
            }
            activeRoom=plan; activeCloud=plan.commands.first; live.clear(); runState = .syncing
            notice="Govee bestätigt: \(plan.commands.count) Gerät(e) · \(screenDevices.count) Ambilight-Gerät(e) · Darstellung am Gerät prüfen."
        } catch {
            if !(error is CancellationError) { message=error.localizedDescription }
            await engine.stop(); await restoreUncancelled(); activeRoom=nil; activeCloud=nil; runState = .idle
        }
        startupTask=nil
    }
    func applyRoomControls() {
        guard let old=activeRoom,runState == .syncing,!switchingMode,!roomApplying,stopTask == nil else { return }
        do {
            let next=try cloud.room.plan(devices:devices,profiles:cloud.musicProfiles)
            let changes=try next.controlChanges(from:old)
            roomApplying=true
            roomControlsTask=Task {
                defer { self.roomApplying=false;self.roomControlsTask=nil }
                do {
                    let credential=self.cloud.key
                    for command in next.commands {
                        try Task.checkCancellation()
                        if changes.commands.contains(command) {
                            let send=Task { try await self.cloud.api.activate(command,key:credential) }
                            try await send.value
                        }
                        try Task.checkCancellation()
                        if let brightness=next.musicBrightness,changes.brightnessIDs.contains(command.device),
                           let device=self.devices.first(where:{$0.id == command.device}) {
                            try self.transport.send(GoveeProtocol.brightness(brightness),to:device.ip)
                        }
                    }
                    try Task.checkCancellation()
                    if !next.ambilightIDs.isEmpty { self.engine.update(devices:self.devices,settings:next.screenSettings(base:self.settings)) }
                    self.activeRoom=next;self.activeCloud=next.commands.first;self.cloud.saveRoom()
                    self.cloud.musicStatus="Regler übernommen · Gerätezuordnung unverändert."
                } catch {
                    if !(error is CancellationError) {
                        self.message=error.localizedDescription
                        // Do not await our own stop barrier from inside this task.
                        Task { await self.stop() }
                    }
                }
            }
        } catch { message=error.localizedDescription }
    }
    func stop() async {
        await modeActivation.cancelAndWait()
        await stopSession()
    }
    private func stopSession() async {
        if let task=stopTask { await task.value; return }
        let task=Task { await self.stopSessionBody() }
        stopTask=task
        await task.value
        stopTask=nil
    }
    private func stopSessionBody() async {
        let controls=roomControlsTask;controls?.cancel();await controls?.value
        if testActive {
            let task=identifyTask; task?.cancel(); await task?.value; return
        }
        if runState == .starting {
            let task=startupTask; task?.cancel(); await task?.value
            return
        }
        guard runState != .stopping else { return }
        let hadOutput = !recovery.isEmpty
        if running {
            let (packets,bytes)=transport.counters()
            let record: [String:Any] = ["date":ISO8601DateFormatter().string(from:Date()),"output":hadOutput,"fps":live.fps,"processing_ms_per_frame":live.workMS,"zones":segmentCount,"udp_packets_since_launch":packets,"udp_bytes_since_launch":bytes,"mode":show.mode.rawValue,"scope":"Frame processing including LAN send; not end-to-end light latency"]
            if let data=try? JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]) {
                try? data.write(to:directory.appendingPathComponent("last-session.json"),options:.atomic)
            }
        }
        runState = .stopping
        await engine.stop()
        await restoreUncancelled()
        activeCloud=nil; activeRoom=nil
        runState = .idle; bandwidth=0; live.clear()
        notice = recoveryAvailable ? "Gestoppt · Wiederherstellung noch offen; beim nächsten Sync-Start wird sie erneut versucht." : (hadOutput ? "Gestoppt · vorherige Lichtwerte zurückgesendet." : "Vorschau beendet · Leuchten unverändert.")
        save()
    }
    private func restoreUncancelled() async {
        let restoration=Task { @MainActor in await self.restore() }
        await restoration.value
    }
    private func restore() async {
        guard !recovery.isEmpty else { return }
        var failed: [RecoveryLight]=[]
        for light in recovery {
            var restored=false
            for attempt in 0..<3 {
              do {
                if light.mode == .dreamview { try transport.send(GoveeProtocol.streamEnabled(false),to:light.ip) }
                try? await Task.sleep(nanoseconds:80_000_000)
                try transport.send(GoveeProtocol.color(light.state.color,kelvin:light.state.kelvin),to:light.ip)
                try? await Task.sleep(nanoseconds:100_000_000)
                try transport.send(GoveeProtocol.brightness(light.state.brightness),to:light.ip)
                try? await Task.sleep(nanoseconds:100_000_000)
                try transport.send(GoveeProtocol.power(light.state.on),to:light.ip)
                try? await Task.sleep(nanoseconds:150_000_000)
                let confirmed=try await transport.snapshot(ip:light.ip)
                guard confirmed.on == light.state.on, confirmed.brightness == max(1,light.state.brightness) else {
                    throw StudioError.message("Lichtwerte noch nicht bestätigt.")
                }
                restored=true
                break
              } catch {
                if attempt < 2 { try? await Task.sleep(nanoseconds:350_000_000) }
              }
            }
            if !restored { failed.append(light) }
        }
        recovery=failed
        if failed.isEmpty { try? FileManager.default.removeItem(at:directory.appendingPathComponent("recovery.json")); recoveryAvailable=false }
        else { try? JSONEncoder().encode(failed).write(to:directory.appendingPathComponent("recovery.json"),options:.atomic); recoveryAvailable=true }
    }
    func recoverPrevious() async {
        guard !busy else { return }
        message=nil
        do {
            try ensureNetwork()
            recovery=try JSONDecoder().decode([RecoveryLight].self,from:Data(contentsOf:directory.appendingPathComponent("recovery.json")))
            runState = .stopping
            await restoreUncancelled()
            notice=recoveryAvailable ? "Wiederherstellung noch offen · Verbindung der Leuchten prüfen.":"Vorherige Lichtwerte wiederhergestellt · bereit für Sync."
            if recoveryAvailable { message="Eine Leuchte bestätigt die Lichtwerte noch nicht. Bitte ihre LAN-Verbindung prüfen und erneut versuchen." }
            runState = .idle
        } catch { message=error.localizedDescription; runState = .idle }
    }
    func beginChannelProbe() {
        guard !busy else { return }
        channelProbe=true
        identifyTask=Task { await identify(); channelProbe=false }
    }
    func beginIdentify() {
        guard !busy else { return }
        identifyTask=Task { await identify() }
    }
    private func identify() async {
        guard !busy, let device=selected else { return }
        guard !recoveryAvailable else { message="Bitte zuerst die Lichtwerte der vorherigen Sitzung wiederherstellen."; return }
        testActive=true; message=nil
        defer { testActive=false; identifyTask=nil }
        do {
            try ensureNetwork()
            let state=try await transport.snapshot(ip:device.ip)
            recovery=[RecoveryLight(ip:device.ip,mode:device.mode,state:state)]
            try JSONEncoder().encode(recovery).write(to:directory.appendingPathComponent("recovery.json"),options:.atomic)
            try transport.send(GoveeProtocol.power(true),to:device.ip)
            try await Task.sleep(nanoseconds:100_000_000)
            try transport.send(GoveeProtocol.brightness(35),to:device.ip)
            try await Task.sleep(nanoseconds:100_000_000)
            if device.mode == .dreamview {
                try transport.send(GoveeProtocol.streamEnabled(true),to:device.ip)
                try await Task.sleep(nanoseconds:120_000_000)
                let count=channelProbe ? show.count(for:device):device.zones.count
                let chosen=channelProbe ? probeChannel:selectedZone
                var colors=[RGB](repeating:RGB(3,3,7),count:count)
                let index=device.reverse ? count-1-chosen:chosen
                colors[max(0,min(colors.count-1,index))]=RGB(20,210,255)
                for _ in 0..<10 {
                    try transport.send(GoveeProtocol.frame(colors,header:device.header,stretch:device.stretch),to:device.ip)
                    try await Task.sleep(nanoseconds:150_000_000)
                }
            } else {
                try transport.send(GoveeProtocol.color(RGB(20,210,255)),to:device.ip)
                try await Task.sleep(nanoseconds:1_500_000_000)
            }
            notice="Test gesendet · Kanal \((channelProbe ? probeChannel:selectedZone)+1). Sichtbare Zuordnung bitte am Gerät prüfen."
        } catch { message=error.localizedDescription }
        await restoreUncancelled()
    }
    func openScreenPrivacy() {
        if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
    }
}
