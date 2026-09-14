import XCTest
import AmbienceCore
@testable import GoveeStudio

final class RoomControlsTests: XCTestCase {
    let devices=[DeviceConfig(id:"a",ip:"127.0.0.1",sku:"H606A"),DeviceConfig(id:"b",ip:"127.0.0.2",sku:"H606A")]
    var profiles: [NativeMusicProfile] { devices.map { NativeMusicProfile(device:$0.id,sku:$0.sku,modes:[.init(name:"Energic",value:3)]) } }
    func testBrightnessOnlyDoesNotRestartInternalMusic() throws {
        var settings=RoomMusicSettings()
        let before=try settings.plan(devices:devices,profiles:profiles)
        settings.musicBrightness=35
        let after=try settings.plan(devices:devices,profiles:profiles)
        let changes=try after.controlChanges(from:before)
        XCTAssertTrue(changes.commands.isEmpty)
        XCTAssertEqual(changes.brightnessIDs,Set(["a","b"]))
        XCTAssertTrue(try after.controlChanges(from:after).brightnessIDs.isEmpty)
    }
    func testRoomPaletteUsesDistinctFixedDeviceColorsAndKeepsMusicCapability() throws {
        var settings=RoomMusicSettings();settings.colorScheme = .neon;settings.musicBrightness=50
        let plan=try settings.plan(devices:devices,profiles:profiles)
        XCTAssertNotEqual(plan.commands[0].value,plan.commands[1].value)
        for command in plan.commands {
            guard case .object(let value)=command.value else { return XCTFail("Expected music parameters") }
            XCTAssertEqual(value["autoColor"],0);XCTAssertEqual(value["musicMode"],3)
            XCTAssertNotNil(value["rgb"]);XCTAssertNil(value["speed"])
        }
    }
    func testOldRoomSettingsKeepDeviceBrightnessAndAutoColor() throws {
        let old=Data(#"{"roles":{},"modes":{},"sensitivity":75,"autoColor":true,"hue":0.85,"ambientGain":0.35}"#.utf8)
        let settings=try JSONDecoder().decode(RoomMusicSettings.self,from:old)
        XCTAssertNil(settings.musicBrightness);XCTAssertEqual(settings.colorScheme,.automatic)
        XCTAssertNil(try settings.plan(devices:devices,profiles:profiles).musicBrightness)
    }
    func testLiveChangesCannotReassignOutputSources() throws {
        var settings=RoomMusicSettings()
        let old=try settings.plan(devices:devices,profiles:profiles)
        settings.roles["b"] = .ambilight
        XCTAssertThrowsError(try settings.plan(devices:devices,profiles:profiles).controlChanges(from:old))
    }
    @MainActor
    func testCredentialPersistsViaStoreAndReloadsWithoutPlaintextFiles() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let store=TestCredentialStore()
        let library=CloudLibrary(directory:folder,credentialStore:store)
        library.key="test-key-not-real";library.saveKey();library.saveRoom()
        XCTAssertTrue(library.keySaved)
        let restarted=CloudLibrary(directory:folder,credentialStore:store)
        XCTAssertEqual(restarted.key,"test-key-not-real");XCTAssertTrue(restarted.keySaved)
        for file in try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) {
            XCTAssertFalse(try String(contentsOf:file).contains("test-key-not-real"))
        }
    }
}
