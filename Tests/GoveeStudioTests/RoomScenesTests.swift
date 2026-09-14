import XCTest
import AmbienceCore
@testable import GoveeStudio

final class RoomScenesTests: XCTestCase {
    let devices=[DeviceConfig(id:"a",ip:"127.0.0.1",sku:"H606A"),DeviceConfig(id:"b",ip:"127.0.0.2",sku:"H61A0")]
    var catalog: CloudSceneCatalog {
        CloudSceneCatalog(groups:devices.enumerated().map { i,d in
            CloudSceneGroup(device:d.id,sku:d.sku,name:d.name,scenes:[CloudScene(device:d.id,sku:d.sku,name:"Scene",kind:"lightScene",value:.number(i+100))])
        })
    }
    func testUsesEachDevicesExactSceneAndRequiresEveryEnabledDevice() throws {
        var selection=RoomSceneSelection()
        selection.sceneIDs["a"]=catalog.groups[0].scenes[0].id
        XCTAssertThrowsError(try selection.plan(devices:devices,catalog:catalog))
        selection.sceneIDs["b"]=catalog.groups[1].scenes[0].id
        let plan=try selection.plan(devices:devices,catalog:catalog)
        XCTAssertEqual(plan.commands.map(\.value),[.number(100),.number(101)])
        XCTAssertEqual(plan.ids,["a","b"])
        XCTAssertEqual(OutputTarget.roomScenes(plan).mode,.scenes)
        selection.sceneIDs["b"]=selection.sceneIDs["a"]
        XCTAssertThrowsError(try selection.plan(devices:devices,catalog:catalog))
    }
    func testDisabledDevicesExcludedAndStaleSelectionsRejected() throws {
        var selected=devices;selected[1].enabled=false
        let selection=RoomSceneSelection(sceneIDs:["a":catalog.groups[0].scenes[0].id,"b":"stale"])
        XCTAssertEqual(try selection.plan(devices:selected,catalog:catalog).ids,["a"])
        XCTAssertThrowsError(try selection.plan(devices:devices,catalog:catalog))
        XCTAssertThrowsError(try selection.plan(devices:[],catalog:catalog))
    }
    @MainActor func testSelectionSurvivesLibraryReload() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let library=CloudLibrary(directory:folder,credentialStore:TestCredentialStore())
        library.roomScenes.sceneIDs=["a":"chosen"]
        library.saveRoomScenes()
        XCTAssertEqual(CloudLibrary(directory:folder,credentialStore:TestCredentialStore()).roomScenes.sceneIDs,["a":"chosen"])
    }
}
