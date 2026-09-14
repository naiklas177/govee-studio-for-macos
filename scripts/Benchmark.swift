import Foundation

@main
struct Benchmark {
    static func main() throws {
        let width=384,height=216,stride=width*4
        let zones=MappingPreset.grid.zones(count:68)
        let pixels=(0..<(stride*height)).map { UInt8(($0*17+11)%256) }
        let start=ProcessInfo.processInfo.systemUptime
        var checksum=0.0
        let iterations=2000
        pixels.withUnsafeBufferPointer { p in
            for _ in 0..<iterations {
                for zone in zones {
                    let color=ColorSampler.average(bytes:p.baseAddress!,width:width,height:height,stride:stride,zone:zone)
                    checksum += color.r+color.g+color.b
                }
            }
        }
        let seconds=ProcessInfo.processInfo.systemUptime-start
        let result: [String:Any] = ["frames":iterations,"zones":zones.count,"source":"synthetic BGRA 384x216", "sampling_ms_per_frame":seconds*1000/Double(iterations),"checksum":checksum,"scope":"CPU color sampling only; excludes ScreenCaptureKit, UI, UDP and physical device latency"]
        print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
    }
}
