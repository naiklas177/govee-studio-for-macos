import Foundation

public struct RGB: Codable, Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    public static let black = RGB(0, 0, 0)
    public var bytes: [UInt8] { [r,g,b].map { UInt8(max(0, min(255, $0.isFinite ? $0.rounded() : 0))) } }
    public func mixed(with other: RGB, amount: Double) -> RGB {
        let a = max(0, min(1, amount))
        return RGB(r+(other.r-r)*a, g+(other.g-g)*a, b+(other.b-b)*a)
    }
    public func adjusted(gain: Double, saturation: Double, blackThreshold: Double) -> RGB {
        if max(r,g,b) < blackThreshold { return .black }
        let gray = r*0.2126 + g*0.7152 + b*0.0722
        return RGB(max(0, min(255, (gray+(r-gray)*saturation)*gain)),
                   max(0, min(255, (gray+(g-gray)*saturation)*gain)),
                   max(0, min(255, (gray+(b-gray)*saturation)*gain)))
    }
}

public struct SampleZone: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
        clamp()
    }
    public mutating func clamp() {
        width = max(0.015, min(1, width.isFinite ? width : 0.1))
        height = max(0.015, min(1, height.isFinite ? height : 0.1))
        x = max(0, min(1-width, x.isFinite ? x : 0))
        y = max(0, min(1-height, y.isFinite ? y : 0))
    }
    public var centerX: Double { x+width/2 }
    public var centerY: Double { y+height/2 }
}

public enum MappingPreset: String, CaseIterable, Codable, Sendable {
    case top = "Oben", bottom = "Unten", left = "Links", right = "Rechts", perimeter = "Bildrand", grid = "Fläche"
    public func zones(count: Int) -> [SampleZone] {
        let n = max(1, min(200, count))
        return (0..<n).map { i in
            let t = Double(i)/Double(n)
            switch self {
            case .top: return SampleZone(x:t, y:0, width:1/Double(n), height:0.18)
            case .bottom: return SampleZone(x:t, y:0.82, width:1/Double(n), height:0.18)
            case .left: return SampleZone(x:0, y:t, width:0.18, height:1/Double(n))
            case .right: return SampleZone(x:0.82, y:t, width:0.18, height:1/Double(n))
            case .grid:
                let cols = Int(ceil(sqrt(Double(n)*1.6)))
                let rows = Int(ceil(Double(n)/Double(cols)))
                return SampleZone(x:Double(i%cols)/Double(cols), y:Double(i/cols)/Double(rows), width:1/Double(cols), height:1/Double(rows))
            case .perimeter:
                let p = (Double(i)+0.5)/Double(n)*4
                let side = Int(p)
                let u = p-Double(side)
                let size = max(0.04,min(0.2,4/Double(n)))
                switch side {
                case 0: return SampleZone(x:u-size/2,y:0,width:size,height:0.15)
                case 1: return SampleZone(x:0.85,y:u-size/2,width:0.15,height:size)
                case 2: return SampleZone(x:1-u-size/2,y:0.85,width:size,height:0.15)
                default: return SampleZone(x:0,y:1-u-size/2,width:0.15,height:size)
                }
            }
        }
    }
}

public enum OutputMode: String, Codable, CaseIterable, Sendable {
    case whole = "Einzelfarbe", dreamview = "DreamView"
}
public enum StreamHeader: Int, Codable, CaseIterable, Sendable {
    case automatic = 0, dream = 250, desktop = 32, chroma = 14
    public var label: String { switch self { case .automatic: return "Automatisch"; case .dream: return "Legacy"; case .desktop: return "Desktop"; case .chroma: return "Chroma" } }
}
public struct DeviceConfig: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var ip: String
    public var sku: String
    public var name: String
    public var enabled = true
    public var gain = 0.55
    public var mode: OutputMode = .dreamview
    public var header: StreamHeader = .automatic
    public var stretch = false
    public var reverse = false
    public var calibrated = false
    public var zones: [SampleZone]
    public init(id: String, ip: String, sku: String, ordinal: Int = 0) {
        self.id = id; self.ip = ip; self.sku = sku
        switch sku {
        case "H606A": name = "Hexagon Ultra \(ordinal+1)"; zones = MappingPreset.grid.zones(count:10)
        case "H61A0": name = "Neon · 3 m"; zones = MappingPreset.bottom.zones(count:18)
        case "H61A2": name = "Neon · 5 m"; zones = MappingPreset.top.zones(count:30)
        default: name = "Govee \(sku)"; zones = MappingPreset.grid.zones(count:1); mode = .whole
        }
    }
    public var isHex: Bool { sku.hasPrefix("H606") }
    public mutating func validate() {
        gain = max(0, min(1, gain.isFinite ? gain : 0.55))
        if zones.isEmpty { zones = MappingPreset.grid.zones(count:1) }
        zones = Array(zones.prefix(84))
        for i in zones.indices { zones[i].clamp() }
    }
}
public struct StudioSettings: Codable, Equatable, Sendable {
    public var fps = 25
    public var smoothing = 0.12
    public var saturation = 1.15
    public var blackThreshold = 8.0
    public var cropBars = true
    public var masterGain = 0.8
    public init() {}
    public mutating func validate() {
        fps = max(5,min(40,fps))
        smoothing = max(0,min(1,smoothing.isFinite ? smoothing : 0.12))
        saturation = max(0,min(2,saturation.isFinite ? saturation : 1.15))
        blackThreshold = max(0,min(50,blackThreshold.isFinite ? blackThreshold : 8))
        masterGain = max(0,min(1,masterGain.isFinite ? masterGain : 0.8))
    }
}
public struct StudioProfile: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var devices: [DeviceConfig]
    public var settings: StudioSettings
    public init(name: String, devices: [DeviceConfig], settings: StudioSettings) {
        self.name = name; self.devices = devices; self.settings = settings
    }
}
public struct SavedWorkspace: Codable {
    public var version = 1
    public var devices: [DeviceConfig]
    public var settings: StudioSettings
    public var profiles: [StudioProfile]
    public init(devices: [DeviceConfig], settings: StudioSettings, profiles: [StudioProfile]) {
        self.devices=devices; self.settings=settings; self.profiles=profiles
    }
}
