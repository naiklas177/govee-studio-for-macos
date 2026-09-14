import Foundation
import AmbienceCore

/// Preserve vendor scene IDs, including {id,paramId}, without inventing local commands.
enum SceneValue: Codable, Hashable {
    case number(Int), object([String:Int])
    init(from decoder: Decoder) throws {
        let c=try decoder.singleValueContainer()
        if let n=try? c.decode(Int.self) { self = .number(n) }
        else { self = .object(try c.decode([String:Int].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c=encoder.singleValueContainer()
        switch self { case .number(let n): try c.encode(n); case .object(let o): try c.encode(o) }
    }
    var stableID: String {
        switch self { case .number(let n): return String(n)
        case .object(let o): return o.keys.sorted().map { "\($0)=\(o[$0]!)" }.joined(separator:",") }
    }
}
struct CloudScene: Codable, Hashable, Identifiable {
    let device: String
    let sku: String
    let name: String
    let kind: String
    let value: SceneValue
    var id: String { device+"/"+kind+"/"+value.stableID }
    var displayName: String { name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "DIY #"+value.stableID:name }
    var label: String { kind == "musicMode" ? "Geräte-Musik":(kind == "diyScene" ? "DIY":"Original") }
}
struct CloudSceneGroup: Codable, Identifiable {
    let device: String
    let sku: String
    let name: String
    var scenes: [CloudScene]
    var updatedAt: Date?
    var error: String?
    var id: String { device }
}
struct CloudSceneCatalog: Codable {
    var groups: [CloudSceneGroup]=[]
}
struct CloudEnvelope: Decodable {
    let code: Int
    let payload: Payload?
    struct Payload: Decodable {
        let sku: String?
        let device: String?
        let capabilities: [Capability]?
    }
    struct Capability: Decodable {
        let instance: String
        let parameters: Parameters?
    }
    struct Parameters: Decodable { let options: [Option]? }
    struct Option: Decodable { let name: String; let value: SceneValue }
    func scenes(device: DeviceConfig,kind: String) throws -> [CloudScene] {
        guard code == 200, let payload, payload.device == device.id, payload.sku == device.sku,
              let caps=payload.capabilities else { throw StudioError.message("Ungültige Govee-Geräteantwort; gespeicherte Auswahl bleibt erhalten.") }
        var seen=Set<String>()
        return caps.filter { $0.instance == kind }.flatMap { $0.parameters?.options ?? [] }.map {
            CloudScene(device:device.id,sku:device.sku,name:$0.name,kind:kind,value:$0.value)
        }.filter { seen.insert($0.id).inserted }
    }
}

protocol CloudSceneServing {
    func fetch(device: DeviceConfig,kind: String,key: String) async throws -> [CloudScene]
    func activate(_ scene: CloudScene,key: String) async throws
}
final class CloudSceneAPI: NSObject, URLSessionTaskDelegate, CloudSceneServing {
    private lazy var session: URLSession = {
        let config=URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest=20; config.timeoutIntervalForResource=25
        config.urlCache=nil; config.httpCookieStorage=nil; config.urlCredentialStorage=nil
        return URLSession(configuration:config,delegate:self,delegateQueue:nil)
    }()
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    static func controlBody(_ scene: CloudScene) throws -> Data {
        struct Body: Encodable {
            var requestId=UUID().uuidString
            let payload: Payload
            struct Payload: Encodable { let sku: String; let device: String; let capability: Capability }
            struct Capability: Encodable { let type: String; let instance: String; let value: SceneValue }
        }
        return try JSONEncoder().encode(Body(payload:.init(sku:scene.sku,device:scene.device,capability:.init(type:scene.kind == "musicMode" ? "devices.capabilities.music_setting":"devices.capabilities.dynamic_scene",instance:scene.kind,value:scene.value))))
    }
    private func request(endpoint: String,body: Data,key: String) async throws -> CloudEnvelope {
        let clean=key.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.contains("\n"), !clean.contains("\r") else { throw StudioError.message("Bitte einen gültigen Govee-API-Key eingeben.") }
        var request=URLRequest(url:URL(string:"https://openapi.api.govee.com/router/api/v1/device/"+endpoint)!)
        request.httpMethod="POST"; request.httpBody=body
        request.setValue(clean,forHTTPHeaderField:"Govee-API-Key")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        let (data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse else { throw StudioError.message("Keine gültige Govee-Antwort.") }
        guard http.statusCode == 200 else { throw StudioError.message("Govee HTTP \(http.statusCode). Bei 401/403 Key prüfen; bei 429 später erneut versuchen.") }
        let envelope=try JSONDecoder().decode(CloudEnvelope.self,from:data)
        guard envelope.code == 200 else { throw StudioError.message("Govee meldet Fehler \(envelope.code).") }
        return envelope
    }
    func fetch(device: DeviceConfig,kind: String,key: String) async throws -> [CloudScene] {
        let body=try JSONSerialization.data(withJSONObject:["requestId":UUID().uuidString,"payload":["device":device.id,"sku":device.sku]])
        let response=try await request(endpoint:kind == "diyScene" ? "diy-scenes":"scenes",body:body,key:key)
        return try response.scenes(device:device,kind:kind)
    }
    func fetchMusicProfiles(key: String) async throws -> [NativeMusicProfile] {
        let clean=key.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !clean.isEmpty,!clean.contains("\n"),!clean.contains("\r") else { throw StudioError.message("Govee-API-Key eingeben.") }
        var request=URLRequest(url:URL(string:"https://openapi.api.govee.com/router/api/v1/user/devices")!)
        request.setValue(clean,forHTTPHeaderField:"Govee-API-Key")
        let (data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse,http.statusCode == 200 else { throw StudioError.message("Musikfähigkeiten konnten nicht abgerufen werden. Key und Verbindung prüfen.") }
        return try NativeMusicProfile.parse(data)
    }
    func activate(_ scene: CloudScene,key: String) async throws {
        _ = try await request(endpoint:"control",body:Self.controlBody(scene),key:key)
    }
}

@MainActor
final class CloudLibrary: ObservableObject {
    @Published var catalog=CloudSceneCatalog()
    @Published var musicProfiles: [NativeMusicProfile]=[]
    @Published var room=RoomMusicSettings()
    @Published var roomScenes=RoomSceneSelection()
    private let roomScenesFile: URL
    @Published var musicStatus="Modi pro Gerät · Änderungen werden beim Start übernommen."
    @Published var loadingMusic=false
    private let musicFile: URL
    private let roomFile: URL
    @Published var key="" // Only Keychain stores the credential; never Codable/UserDefaults.
    @Published var keySaved=false
    @Published var keyStatus="Dauerhaft speichern: künftig ohne erneute Eingabe."
    private let credentialStore: CredentialStore
    @Published var refreshing=false
    @Published var status="Katalog lokal verfügbar. Zum Aktualisieren oder Starten wird Internet benötigt."
    let api: CloudSceneServing
    private let file: URL
    init(directory: URL,api: CloudSceneServing=CloudSceneAPI(),credentialStore: CredentialStore=KeychainCredentialStore()) {
        self.credentialStore=credentialStore
        self.api=api
        musicFile=directory.appendingPathComponent("govee-music-profiles.json")
        roomFile=directory.appendingPathComponent("room-music.json")
        roomScenesFile=directory.appendingPathComponent("room-scenes.json")
        file=directory.appendingPathComponent("govee-scenes.json")
        do {
            if let saved=try credentialStore.load(),!saved.isEmpty { key=saved;keySaved=true;keyStatus="Automatisch geladen · bleibt nach App-Neustart verfügbar." }
        } catch { keyStatus=error.localizedDescription }
        if let data=try? Data(contentsOf:roomScenesFile),let cached=try? JSONDecoder().decode(RoomSceneSelection.self,from:data) { roomScenes=cached }
        if let data=try? Data(contentsOf:musicFile),let cached=try? JSONDecoder().decode([NativeMusicProfile].self,from:data) { musicProfiles=cached }
        if let data=try? Data(contentsOf:roomFile),let cached=try? JSONDecoder().decode(RoomMusicSettings.self,from:data) { room=cached }
        if let data=try? Data(contentsOf:file),let cached=try? JSONDecoder().decode(CloudSceneCatalog.self,from:data) { catalog=cached }
    }
    func saveRoomScenes() {
        do { try JSONEncoder().encode(roomScenes).write(to:roomScenesFile,options:.atomic) }
        catch { status="Raum-Auswahl konnte nicht gespeichert werden: \(error.localizedDescription)" }
    }
    func saveKey() {
        let clean=key.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !clean.isEmpty,!clean.contains("\n"),!clean.contains("\r") else { keyStatus="Bitte einen gültigen Key eingeben.";return }
        do { try credentialStore.save(clean);key=clean;keySaved=true;keyStatus="Dauerhaft im macOS-Schlüsselbund gespeichert." }
        catch { keySaved=false;keyStatus=error.localizedDescription }
    }
    func forgetKey() {
        do { try credentialStore.remove();key="";keySaved=false;keyStatus="Key aus dem Schlüsselbund entfernt." }
        catch { keyStatus=error.localizedDescription }
    }
    func saveRoom() {
        do { try JSONEncoder().encode(room).write(to:roomFile,options:.atomic) }
        catch { musicStatus="Raumkonfiguration nicht gespeichert: \(error.localizedDescription)" }
    }
    func refreshMusic(devices: [DeviceConfig]) async {
        guard !loadingMusic else { return }; loadingMusic=true; defer { loadingMusic=false }
        do {
            let profiles=try await CloudSceneAPI().fetchMusicProfiles(key:key)
            let known=profiles.filter { profile in devices.contains(where:{$0.id == profile.device && $0.sku == profile.sku}) }
            try JSONEncoder().encode(known).write(to:musicFile,options:.atomic)
            musicProfiles=known; musicStatus="Musikmodi für \(known.count) Geräte lokal gespeichert."
        } catch { musicStatus=error.localizedDescription }
    }
    func refresh(devices: [DeviceConfig]) async {
        guard !refreshing else { return }
        guard !key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { status="API-Key eingeben, um den Katalog abzurufen."; return }
        refreshing=true; defer { refreshing=false }
        let credential=key
        for device in devices {
            status="Lade Original & DIY für \(device.name) …"
            var group=catalog.groups.first { $0.device == device.id && $0.sku == device.sku } ?? CloudSceneGroup(device:device.id,sku:device.sku,name:device.name,scenes:[])
            var errors:[String]=[]
            for kind in ["lightScene","diyScene"] {
                do {
                    let scenes=try await api.fetch(device:device,kind:kind,key:credential)
                    group.scenes.removeAll { $0.kind == kind }; group.scenes += scenes
                } catch { errors.append(error.localizedDescription) }
            }
            group.error=errors.isEmpty ? nil:errors.joined(separator:" · ")
            if errors.isEmpty { group.updatedAt=Date() }
            if let i=catalog.groups.firstIndex(where:{$0.device == device.id}) { catalog.groups[i]=group } else { catalog.groups.append(group) }
        }
        do {
            try JSONEncoder().encode(catalog).write(to:file,options:.atomic)
            status="\(catalog.groups.reduce(0){$0+$1.scenes.count}) Einträge lokal gespeichert · \(catalog.groups.filter{$0.error != nil}.count) Geräte mit Abruffehlern."
        } catch { status="Katalog geladen, aber nicht gespeichert: \(error.localizedDescription)" }
    }
}

enum OutputTarget {
    case local(ExperienceMode)
    case cloud(CloudScene)
    case room(RoomOutputPlan)
    case roomScenes(RoomOutputPlan)
    var mode: ExperienceMode { switch self { case .roomScenes: return .scenes; case .room: return .music; case .local(let mode): return mode; case .cloud(let scene): return scene.kind == "musicMode" ? .music:.scenes } }
}
