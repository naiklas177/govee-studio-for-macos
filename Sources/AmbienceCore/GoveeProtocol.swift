import Foundation

public enum GoveeProtocol {
    public enum PacketError: Error { case invalidCount }
    public static func command(_ cmd: String, data: [String: Any] = [:]) -> Data {
        // All callers construct finite, JSON-compatible values.
        (try? JSONSerialization.data(withJSONObject: ["msg":["cmd":cmd,"data":data]], options: [.sortedKeys])) ?? Data()
    }
    public static let scan = command("scan",data:["account_topic":"reserve"])
    public static let status = command("devStatus")
    public static func power(_ on: Bool) -> Data { command("turn",data:["value":on ? 1:0]) }
    public static func brightness(_ value: Int) -> Data { command("brightness",data:["value":max(1,min(100,value))]) }
    public static func color(_ color: RGB, kelvin: Int = 0) -> Data {
        let b=color.bytes
        return command("colorwc",data:["color":["r":Int(b[0]),"g":Int(b[1]),"b":Int(b[2])],"colorTemInKelvin":max(0,min(9000,kelvin))])
    }
    public static func streamEnabled(_ value: Bool) -> Data {
        command("razer",data:["pt": value ? "uwABsQEK":"uwABsQAL"])
    }
    public static func frameBytes(_ colors: [RGB], header: StreamHeader = .automatic, stretch: Bool = false) throws -> [UInt8] {
        guard (1...84).contains(colors.count) else { throw PacketError.invalidCount }
        let payloadLength = header == .automatic ? 2+colors.count*3 : header.rawValue
        var bytes: [UInt8] = [0xBB,0x00,UInt8(payloadLength),0xB0,stretch ? 1:0,UInt8(colors.count)]
        for color in colors { bytes.append(contentsOf:color.bytes) }
        bytes.append(bytes.reduce(0,^))
        return bytes
    }
    public static func frame(_ colors: [RGB], header: StreamHeader = .automatic, stretch: Bool = false) throws -> Data {
        command("razer",data:["pt":Data(try frameBytes(colors,header:header,stretch:stretch)).base64EncodedString()])
    }
}
