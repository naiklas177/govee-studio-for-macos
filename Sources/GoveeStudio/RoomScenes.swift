import Foundation
import AmbienceCore

struct RoomSceneSelection: Codable {
    var sceneIDs: [String:String] = [:]
    func plan(devices: [DeviceConfig],catalog: CloudSceneCatalog) throws -> RoomOutputPlan {
        let commands = try devices.filter(\.enabled).map { device -> CloudScene in
            guard let id=sceneIDs[device.id],
                  let scene=catalog.groups.first(where:{$0.device == device.id && $0.sku == device.sku})?.scenes.first(where:{$0.id == id && $0.device == device.id && $0.sku == device.sku && $0.kind == "lightScene"}) else {
                throw StudioError.message("Originalszene für \(device.name) auswählen.")
            }
            return scene
        }
        let plan=RoomOutputPlan(commands:commands,ambilightIDs:[],ambientGain:0)
        try plan.validate(devices:devices)
        return plan
    }
}
