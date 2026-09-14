import Foundation
import Darwin
import AmbienceCore

struct DeviceAnnouncement {
    let id: String
    let ip: String
    let sku: String
}
struct LightState: Codable {
    let on: Bool
    let brightness: Int
    let color: RGB
    let kelvin: Int
}
struct RecoveryLight: Codable {
    let ip: String
    let mode: OutputMode
    let state: LightState
}

enum StudioError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

/// One socket owns the response port. All IO is serialized; frame sends are synchronous
/// on this short-lived queue, so output cannot accumulate an unbounded frame backlog.
final class LANTransport: @unchecked Sendable {
    private let queue = DispatchQueue(label:"studio.govee.lan",qos:.userInitiated)
    private var socketFD: Int32 = -1
    private var reader: DispatchSourceRead?
    private var states: [String:(LightState,Date)] = [:]
    var onDevice: ((DeviceAnnouncement)->Void)?
    var onState: ((String,LightState)->Void)?
    var onError: ((String)->Void)?
    private(set) var packets: Int = 0
    private(set) var bytesSent: Int = 0

    func open() throws {
        try queue.sync {
            guard socketFD < 0 else { return }
            let fd=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP)
            guard fd >= 0 else { throw StudioError.message("UDP-Socket konnte nicht geöffnet werden.") }
            var addr=sockaddr_in()
            addr.sin_len=UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family=sa_family_t(AF_INET)
            addr.sin_port=UInt16(4002).bigEndian
            addr.sin_addr.s_addr=INADDR_ANY
            let result=withUnsafePointer(to:&addr) { pointer in
                pointer.withMemoryRebound(to:sockaddr.self,capacity:1) { Darwin.bind(fd,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard result == 0 else {
                let reason=String(cString:strerror(errno)); Darwin.close(fd)
                throw StudioError.message("UDP-Port 4002 ist nicht verfügbar (\(reason)). Andere Govee-Apps bitte schließen und erneut suchen.")
            }
            var ttl: UInt8=1
            setsockopt(fd,IPPROTO_IP,IP_MULTICAST_TTL,&ttl,socklen_t(MemoryLayout.size(ofValue:ttl)))
            _ = fcntl(fd,F_SETFL,O_NONBLOCK)
            socketFD=fd
            let source=DispatchSource.makeReadSource(fileDescriptor:fd,queue:queue)
            source.setEventHandler { [weak self] in self?.receive() }
            source.setCancelHandler { Darwin.close(fd) }
            reader=source
            source.resume()
        }
    }
    func close() {
        queue.sync { reader?.cancel(); reader=nil; socketFD = -1 }
    }
    deinit { reader?.cancel() }
    private func receive() {
        var buffer=[UInt8](repeating:0,count:8192)
        while true {
            var addr=sockaddr_in()
            var size=socklen_t(MemoryLayout<sockaddr_in>.size)
            let count=withUnsafeMutablePointer(to:&addr) { p in
                p.withMemoryRebound(to:sockaddr.self,capacity:1) { recvfrom(socketFD,&buffer,buffer.count,0,$0,&size) }
            }
            guard count > 0 else { break }
            var ipBuffer=[CChar](repeating:0,count:Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET,&addr.sin_addr,&ipBuffer,socklen_t(INET_ADDRSTRLEN))
            let ip=String(cString:ipBuffer)
            guard let root=(try? JSONSerialization.jsonObject(with:Data(buffer.prefix(count)))) as? [String:Any],
                  let msg=root["msg"] as? [String:Any], let command=msg["cmd"] as? String,
                  let data=msg["data"] as? [String:Any] else { continue }
            if command == "scan", let sku=data["sku"] as? String, let id=data["device"] as? String {
                onDevice?(DeviceAnnouncement(id:id,ip:ip,sku:sku))
            } else if command == "devStatus", let on=data["onOff"] as? Int, let brightness=data["brightness"] as? Int,
                      let color=data["color"] as? [String:Int] {
                let state=LightState(on:on != 0,brightness:brightness,color:RGB(Double(color["r"] ?? 0),Double(color["g"] ?? 0),Double(color["b"] ?? 0)),kelvin:data["colorTemInKelvin"] as? Int ?? 0)
                states[ip]=(state,Date())
                onState?(ip,state)
            }
        }
    }
    func send(_ data: Data, to ip: String, port: UInt16 = 4003) throws {
        try queue.sync {
            guard socketFD >= 0 else { throw StudioError.message("LAN-Verbindung ist geschlossen.") }
            var addr=sockaddr_in()
            addr.sin_len=UInt8(MemoryLayout<sockaddr_in>.size); addr.sin_family=sa_family_t(AF_INET)
            addr.sin_port=port.bigEndian
            guard inet_pton(AF_INET,ip,&addr.sin_addr) == 1 else { throw StudioError.message("Ungültige Geräteadresse: \(ip)") }
            let sent=data.withUnsafeBytes { bytes in
                withUnsafePointer(to:&addr) { p in
                    p.withMemoryRebound(to:sockaddr.self,capacity:1) { sendto(socketFD,bytes.baseAddress,data.count,0,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) }
                }
            }
            guard sent == data.count else { throw StudioError.message("UDP-Ausgabe an \(ip) fehlgeschlagen: \(String(cString:strerror(errno)))") }
            packets += 1; bytesSent += sent
        }
    }
    func discover() throws { try send(GoveeProtocol.scan,to:"239.255.255.250",port:4001) }
    func query(ip: String) throws { try send(GoveeProtocol.status,to:ip) }
    func snapshot(ip: String) async throws -> LightState {
        let since=Date()
        for _ in 0..<3 {
            try query(ip:ip)
            for _ in 0..<5 {
                try await Task.sleep(nanoseconds:100_000_000)
                if let state=queue.sync(execute:{states[ip]}), state.1 >= since { return state.0 }
            }
        }
        throw StudioError.message("\(ip) antwortet nicht auf die Statusabfrage. Die Ausgabe wurde nicht gestartet.")
    }
    func counters() -> (Int,Int) { queue.sync { (packets,bytesSent) } }
}
