import Foundation
import AmbienceCore

struct NativeMusicProfile: Codable, Equatable {
    struct Mode: Codable, Equatable { let name: String; let value: Int }
    let device: String
    let sku: String
    let modes: [Mode]
    static func parse(_ data: Data) throws -> [NativeMusicProfile] {
        guard let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],root["code"] as? Int == 200,let devices=root["data"] as? [[String:Any]] else { throw StudioError.message("Govee liefert keine gültigen Musikfähigkeiten.") }
        return devices.compactMap { device in
            guard let id=device["device"] as? String,let sku=device["sku"] as? String,
                  let caps=device["capabilities"] as? [[String:Any]],let cap=caps.first(where:{$0["instance"] as? String == "musicMode"}),
                  let params=cap["parameters"] as? [String:Any],let fields=params["fields"] as? [[String:Any]],
                  let field=fields.first(where:{$0["fieldName"] as? String == "musicMode"}),let options=field["options"] as? [[String:Any]] else { return nil }
            let modes=options.compactMap { o -> Mode? in
                guard let name=o["name"] as? String,let value=o["value"] as? Int else { return nil }
                return Mode(name:name,value:value)
            }
            return modes.isEmpty ? nil:NativeMusicProfile(device:id,sku:sku,modes:modes)
        }
    }
}
enum RoomLightRole: String, Codable, CaseIterable {
    case music="Govee-Musik", ambilight="Ambilight", off="Nicht verwenden"
}
enum RoomColorScheme: String, Codable, CaseIterable {
    case automatic="Govee-Automatik", neon="Neon Duo", sunset="Sunset", glacier="Glacier", ultraviolet="Ultraviolet", ember="Glut", custom="Eigene Farbe"
    var palette: [RGB] {
        switch self {
        case .automatic:return [RGB(0,240,180),RGB(255,20,160),RGB(100,40,255)]
        case .neon:return [RGB(255,15,150),RGB(0,230,255),RGB(115,20,255)]
        case .sunset:return [RGB(255,65,5),RGB(255,0,100),RGB(95,10,255)]
        case .glacier:return [RGB(0,80,255),RGB(0,230,255),RGB(85,145,255)]
        case .ultraviolet:return [RGB(85,0,255),RGB(200,0,255),RGB(255,0,115)]
        case .ember:return [RGB(255,35,3),RGB(255,125,5),RGB(255,190,35)]
        case .custom:return []
        }
    }
}
struct RoomMusicSettings: Codable {
    var roles: [String:RoomLightRole]=[:]
    var modes: [String:Int]=[:]
    var sensitivity=75.0
    var autoColor=true
    var hue=0.85
    var ambientGain=0.35
    var musicBrightness: Double?
    var scheme: RoomColorScheme?
    var ambientSaturation: Double?
    var ambientSmoothing: Double?
    var colorScheme: RoomColorScheme {
        get { scheme ?? (autoColor ? .automatic:.custom) }
        set { scheme=newValue;autoColor=newValue == .automatic }
    }
    func screenSettings(base: StudioSettings) -> StudioSettings {
        var result=base
        result.masterGain=ambientGain
        if let saturation=ambientSaturation { result.saturation=saturation }
        if let smoothing=ambientSmoothing { result.smoothing=smoothing }
        result.validate();return result
    }
    func role(_ device: DeviceConfig) -> RoomLightRole { roles[device.id] ?? .music }
    func mode(_ profile: NativeMusicProfile) -> NativeMusicProfile.Mode? {
        profile.modes.first(where:{$0.value == modes[profile.device]}) ?? profile.modes.first(where:{$0.name == (profile.sku == "H606A" ? "Windmill":"Rolling")}) ?? profile.modes.first
    }
    func plan(devices: [DeviceConfig],profiles: [NativeMusicProfile]) throws -> RoomOutputPlan {
        var commands:[CloudScene]=[], screen:[String]=[]
        for device in devices where device.enabled {
            switch role(device) {
            case .off: continue
            case .ambilight: screen.append(device.id)
            case .music:
                guard let profile=profiles.first(where:{$0.device == device.id && $0.sku == device.sku}),let mode=mode(profile) else { throw StudioError.message("Musikmodi für \(device.name) zuerst abrufen oder Gerät anders zuordnen.") }
                let safeSensitivity=sensitivity.isFinite ? max(0,min(100,sensitivity)):75
                let scheme=colorScheme
                var value=["musicMode":mode.value,"sensitivity":Int(safeSensitivity),"autoColor":scheme == .automatic ? 1:0]
                if scheme != .automatic {
                    let colors=scheme.palette
                    let color=colors.isEmpty ? ShowRenderer.hue(hue.isFinite ? hue:0.85):colors[commands.count%colors.count]
                    let rgb=color.bytes
                    value["rgb"]=Int(rgb[0])<<16 | Int(rgb[1])<<8 | Int(rgb[2])
                }
                commands.append(CloudScene(device:device.id,sku:device.sku,name:"Govee · "+mode.name,kind:"musicMode",value:.object(value)))
            }
        }
        let plan=RoomOutputPlan(commands:commands,ambilightIDs:screen,ambientGain:ambientGain.isFinite ? max(0,min(1,ambientGain)):0.35,musicBrightness:musicBrightness.map { Int($0.isFinite ? max(1,min(100,$0)):65) },ambientSaturation:ambientSaturation,ambientSmoothing:ambientSmoothing)
        try plan.validate(devices:devices)
        return plan
    }
}
struct RoomOutputPlan {
    let commands: [CloudScene]
    let ambilightIDs: [String]
    let ambientGain: Double
    var musicBrightness: Int? = nil
    var ambientSaturation: Double? = nil
    var ambientSmoothing: Double? = nil
    func screenSettings(base: StudioSettings) -> StudioSettings {
        var result=base;result.masterGain=ambientGain
        if let saturation=ambientSaturation { result.saturation=saturation }
        if let smoothing=ambientSmoothing { result.smoothing=smoothing }
        result.validate();return result
    }
    var ids: [String] { commands.map(\.device)+ambilightIDs }
    func controlChanges(from old: RoomOutputPlan) throws -> (commands: [CloudScene],brightnessIDs: Set<String>) {
        guard Set(commands.map(\.device)) == Set(old.commands.map(\.device)),Set(ambilightIDs) == Set(old.ambilightIDs),old.commands.allSatisfy({$0.kind == "musicMode"}) else { throw StudioError.message("Gerätezuordnung geändert. Bitte Raum-Musik neu starten.") }
        let changed=commands.filter { !old.commands.contains($0) }
        let brightnessTargets=musicBrightness == nil ? []:(musicBrightness != old.musicBrightness ? commands:changed)
        return (changed,Set(brightnessTargets.map(\.device)))
    }
    func validate(devices: [DeviceConfig]) throws {
        guard !commands.isEmpty,Set(ids).count == ids.count else { throw StudioError.message("Mindestens ein Musikgerät wählen. Jedes Gerät darf nur eine Ausgabequelle haben.") }
        for command in commands {
            guard devices.contains(where:{$0.id == command.device && $0.sku == command.sku && $0.enabled}) else { throw StudioError.message("Ein gewähltes Musikgerät ist nicht mehr aktiviert.") }
        }
        guard ambilightIDs.allSatisfy({ id in devices.contains(where:{$0.id == id && $0.enabled}) }) else { throw StudioError.message("Ein Ambilight-Gerät ist nicht mehr aktiviert.") }
    }
}
