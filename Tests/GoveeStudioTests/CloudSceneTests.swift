import XCTest
import AmbienceCore
@testable import GoveeStudio

final class CloudSceneTests: XCTestCase {
    private let device=DeviceConfig(id:"test-device",ip:"127.0.0.1",sku:"H606A",ordinal:0)
    func testCompoundIDsAndUnnamedDIYSurviveCatalogRoundTrip() throws {
        let raw=Data(#"{"code":200,"payload":{"sku":"H606A","device":"test-device","capabilities":[{"instance":"lightScene","parameters":{"options":[{"name":"Cube","value":{"id":6950,"paramId":9653}},{"name":"Cube","value":{"id":6950,"paramId":9654}}]}},{"instance":"diyScene","parameters":{"options":[{"name":"","value":123}]}}]}}"#.utf8)
        let envelope=try JSONDecoder().decode(CloudEnvelope.self,from:raw)
        let original=try envelope.scenes(device:device,kind:"lightScene")
        XCTAssertEqual(original.count,2)
        XCTAssertNotEqual(original[0].id,original[1].id)
        let diy=try envelope.scenes(device:device,kind:"diyScene")
        XCTAssertEqual(diy[0].displayName,"DIY #123")
        let all=original+diy
        XCTAssertEqual(try JSONDecoder().decode([CloudScene].self,from:JSONEncoder().encode(all)),all)
    }
    func testCatalogRejectsWrongDeviceAndServerFailure() throws {
        for raw in [#"{"code":200,"payload":{"sku":"H606A","device":"another-device","capabilities":[]}}"#,#"{"code":400}"#] {
            let response=try JSONDecoder().decode(CloudEnvelope.self,from:Data(raw.utf8))
            XCTAssertThrowsError(try response.scenes(device:device,kind:"lightScene"))
        }
    }
    func testControlUsesExactDeviceAndCompoundValueWithoutCredentials() throws {
        let scene=CloudScene(device:device.id,sku:device.sku,name:"Cube",kind:"lightScene",value:.object(["id":6950,"paramId":9653]))
        let body=try CloudSceneAPI.controlBody(scene)
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:body) as? [String:Any])
        let payload=try XCTUnwrap(root["payload"] as? [String:Any])
        XCTAssertEqual(payload["device"] as? String,device.id)
        let capability=try XCTUnwrap(payload["capability"] as? [String:Any])
        XCTAssertEqual(capability["type"] as? String,"devices.capabilities.dynamic_scene")
        XCTAssertEqual(capability["value"] as? [String:Int],["id":6950,"paramId":9653])
        XCTAssertFalse(String(decoding:body,as:UTF8.self).contains("API-Key"))
    }
    func testNativeMusicUsesMusicCapabilityAndMusicTab() throws {
        let music=CloudScene(device:device.id,sku:device.sku,name:"Rhythm",kind:"musicMode",value:.object(["musicMode":1,"sensitivity":75,"autoColor":1]))
        let data=try CloudSceneAPI.controlBody(music)
        let root=try JSONSerialization.jsonObject(with:data) as! [String:Any]
        let payload=root["payload"] as! [String:Any]
        let capability=payload["capability"] as! [String:Any]
        XCTAssertEqual(capability["type"] as? String,"devices.capabilities.music_setting")
        XCTAssertEqual(capability["value"] as? [String:Int],["musicMode":1,"sensitivity":75,"autoColor":1])
        XCTAssertEqual(OutputTarget.cloud(music).mode,.music)
    }
    @MainActor
    func testFailedDIYRefreshPreservesCacheAndNeverStoresKey() async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let api=FakeCloudAPI()
        let library=CloudLibrary(directory:directory,api:api,credentialStore:TestCredentialStore())
        library.key="test-session-secret"
        await library.refresh(devices:[device])
        XCTAssertEqual(library.catalog.groups[0].scenes.count,2)
        api.failDIY=true
        await library.refresh(devices:[device])
        XCTAssertEqual(library.catalog.groups[0].scenes.count,2)
        XCTAssertNotNil(library.catalog.groups[0].error)
        let file=directory.appendingPathComponent("govee-scenes.json")
        XCTAssertFalse(try String(contentsOf:file).contains("test-session-secret"))
        let reopened=CloudLibrary(directory:directory,api:api,credentialStore:TestCredentialStore())
        XCTAssertTrue(reopened.key.isEmpty)
        XCTAssertEqual(reopened.catalog.groups[0].scenes.count,2)
    }
    @MainActor
    func testCloudToLocalSwitchSharesRestorationBarrier() async {
        let queue=ModeActivationQueue<OutputTarget>()
        let scene=CloudScene(device:device.id,sku:device.sku,name:"Cube",kind:"lightScene",value:.number(1))
        var events:[String]=[]
        queue.stopCurrent={ events.append("restore"); try? await Task.sleep(nanoseconds:15_000_000); events.append("restored") }
        queue.start={ target in
            switch target { case .roomScenes: events.append("scenes"); case .room: events.append("room"); case .cloud: events.append("cloud"); case .local: events.append("local") }
        }
        queue.request(.cloud(scene))
        try? await Task.sleep(nanoseconds:40_000_000)
        queue.request(.local(.music))
        try? await Task.sleep(nanoseconds:40_000_000)
        XCTAssertEqual(events,["restore","restored","cloud","restore","restored","local"])
    }
}
private final class FakeCloudAPI: CloudSceneServing {
    var failDIY=false
    func fetch(device: DeviceConfig,kind: String,key: String) async throws -> [CloudScene] {
        if failDIY && kind == "diyScene" { throw URLError(.notConnectedToInternet) }
        return [CloudScene(device:device.id,sku:device.sku,name:kind,kind:kind,value:.number(1))]
    }
    func activate(_ scene: CloudScene,key: String) async throws { XCTFail("Refresh must not control lights") }
}

final class TestCredentialStore: CredentialStore {
    var value: String?
    func load() throws -> String? { value }
    func save(_ key: String) throws { value=key }
    func remove() throws { value=nil }
}
