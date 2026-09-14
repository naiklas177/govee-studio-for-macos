import XCTest
import AmbienceCore
@testable import GoveeStudio

final class RoomMusicTests: XCTestCase {
    let hex=DeviceConfig(id:"hex",ip:"127.0.0.1",sku:"H606A")
    let strip=DeviceConfig(id:"strip",ip:"127.0.0.2",sku:"H61A2")
    var profiles: [NativeMusicProfile] {
        [NativeMusicProfile(device:"hex",sku:"H606A",modes:[.init(name:"Rhythm",value:1),.init(name:"Windmill",value:4)]),
         NativeMusicProfile(device:"strip",sku:"H61A2",modes:[.init(name:"Rhythm",value:2),.init(name:"Rolling",value:4)])]
    }
    func testAllRoomUsesEachDevicesOwnModeIDs() throws {
        var settings=RoomMusicSettings()
        let defaults=try settings.plan(devices:[hex,strip],profiles:profiles)
        XCTAssertEqual(defaults.commands.map(\.name),["Govee · Windmill","Govee · Rolling"])
        settings.modes=["hex":1,"strip":2]
        let plan=try settings.plan(devices:[hex,strip],profiles:profiles)
        XCTAssertEqual(plan.commands.map(\.value),[.object(["musicMode":1,"sensitivity":75,"autoColor":1]),.object(["musicMode":2,"sensitivity":75,"autoColor":1])])
        XCTAssertTrue(plan.ambilightIDs.isEmpty)
    }
    func testHybridAssignsDisjointSourcesAndExcludesDisabledDevices() throws {
        var settings=RoomMusicSettings();settings.roles[strip.id] = .ambilight
        let plan=try settings.plan(devices:[hex,strip],profiles:profiles)
        XCTAssertEqual(plan.commands.map(\.device),[hex.id])
        XCTAssertEqual(plan.ambilightIDs,[strip.id])
        XCTAssertTrue(Set(plan.commands.map(\.device)).isDisjoint(with:plan.ambilightIDs))
        var disabled=strip;disabled.enabled=false
        XCTAssertEqual(try settings.plan(devices:[hex,disabled],profiles:profiles).ids,[hex.id])
    }
    func testDuplicateConflictingAndStaleTargetsAreRejected() throws {
        let command=CloudScene(device:hex.id,sku:hex.sku,name:"Windmill",kind:"musicMode",value:.number(4))
        XCTAssertThrowsError(try RoomOutputPlan(commands:[command],ambilightIDs:[hex.id],ambientGain:0.4).validate(devices:[hex]))
        XCTAssertThrowsError(try RoomOutputPlan(commands:[command,command],ambilightIDs:[],ambientGain:0.4).validate(devices:[hex]))
        XCTAssertThrowsError(try RoomOutputPlan(commands:[command],ambilightIDs:["missing"],ambientGain:0.4).validate(devices:[hex]))
        XCTAssertThrowsError(try RoomMusicSettings().plan(devices:[hex,strip],profiles:[]))
    }
    func testCapabilityParsingPreservesDifferentModelIDs() throws {
        let data=Data(#"{"code":200,"data":[{"device":"hex","sku":"H606A","capabilities":[{"instance":"musicMode","parameters":{"fields":[{"fieldName":"musicMode","options":[{"name":"Rhythm","value":1}]}]}}]},{"device":"strip","sku":"H61A2","capabilities":[{"instance":"musicMode","parameters":{"fields":[{"fieldName":"musicMode","options":[{"name":"Rhythm","value":2}]}]}}]}]}"#.utf8)
        let parsed=try NativeMusicProfile.parse(data)
        XCTAssertEqual(parsed.map { $0.modes[0].value },[1,2])
        XCTAssertThrowsError(try NativeMusicProfile.parse(Data(#"{"code":401}"#.utf8)))
    }
    func testRoomSettingsRoundTripDoesNotAlterLocalShowOrLayout() throws {
        var settings=RoomMusicSettings();settings.roles[strip.id] = .ambilight;settings.ambientGain=0.42;settings.modes[hex.id]=3
        let saved=try JSONDecoder().decode(RoomMusicSettings.self,from:JSONEncoder().encode(settings))
        XCTAssertEqual(saved.role(strip),.ambilight)
        XCTAssertEqual(saved.ambientGain,0.42)
        XCTAssertEqual(saved.modes[hex.id],3)
        XCTAssertEqual(strip.zones.count,30)
    }
}
