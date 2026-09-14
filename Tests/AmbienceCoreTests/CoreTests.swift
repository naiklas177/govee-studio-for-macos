import XCTest
@testable import AmbienceCore

final class CoreTests: XCTestCase {
    func testKnownRazerFrameAndChecksum() throws {
        let result=try GoveeProtocol.frameBytes([RGB(255,0,0),RGB(0,0,255)],header:.dream)
        XCTAssertEqual(result,[0xBB,0,0xFA,0xB0,0,2,255,0,0,0,0,255,0xF3])
        XCTAssertEqual(result.reduce(0,^),0)
        let wrapped=try JSONSerialization.jsonObject(with:GoveeProtocol.frame([RGB(255,0,0),RGB(0,0,255)],header:.dream)) as! [String:Any]
        let msg=wrapped["msg"] as! [String:Any]
        XCTAssertEqual(msg["cmd"] as? String,"razer")
        let encoded=(msg["data"] as! [String:String])["pt"]!
        XCTAssertEqual(Data(base64Encoded:encoded),Data(result))
    }
    func testAutomaticHeaderUsesActualPayloadLength() throws {
        for count in [1,10,18,30,84] {
            let packet=try GoveeProtocol.frameBytes(Array(repeating:RGB(80,120,240),count:count))
            XCTAssertEqual(Int(packet[2]),2+count*3)
            XCTAssertEqual(Int(packet[2]),packet.count-5)
            XCTAssertEqual(packet[5],UInt8(count))
            XCTAssertEqual(packet.reduce(0,^),0)
        }
        XCTAssertEqual(try GoveeProtocol.frameBytes([RGB(255,0,0),RGB(0,0,255)]),[0xBB,0,8,0xB0,0,2,255,0,0,0,0,255,1])
    }
    func testRejectInvalidSegmentCounts() {
        XCTAssertThrowsError(try GoveeProtocol.frameBytes([]))
        XCTAssertThrowsError(try GoveeProtocol.frameBytes(Array(repeating:.black,count:85)))
        XCTAssertNoThrow(try GoveeProtocol.frameBytes(Array(repeating:.black,count:84)))
    }
    func testActivationPackets() throws {
        for (on,expected) in [(true,[UInt8](arrayLiteral:0xBB,0,1,0xB1,1,0x0A)),(false,[UInt8](arrayLiteral:0xBB,0,1,0xB1,0,0x0B))] {
            let root=try JSONSerialization.jsonObject(with:GoveeProtocol.streamEnabled(on)) as! [String:Any]
            let msg=root["msg"] as! [String:Any]
            let data=msg["data"] as! [String:String]
            XCTAssertEqual(Data(base64Encoded:data["pt"]!),Data(expected))
        }
    }
    func testZoneBoundariesAndNonFiniteValues() {
        var zone=SampleZone(x:-2,y:4,width:2,height:0)
        XCTAssertEqual(zone.x,0); XCTAssertEqual(zone.width,1)
        XCTAssertEqual(zone.y+zone.height,1,accuracy:0.000001)
        zone.x = .nan; zone.width = .infinity; zone.clamp()
        XCTAssertTrue(zone.x.isFinite); XCTAssertTrue(zone.width.isFinite)
    }
    func testAllMappingPresetsStayInsideDisplay() {
        for preset in MappingPreset.allCases {
            for count in [1,10,18,30,200] {
                let zones=preset.zones(count:count)
                XCTAssertEqual(zones.count,count)
                for z in zones {
                    XCTAssertGreaterThanOrEqual(z.x,0); XCTAssertGreaterThanOrEqual(z.y,0)
                    XCTAssertLessThanOrEqual(z.x+z.width,1.000001); XCTAssertLessThanOrEqual(z.y+z.height,1.000001)
                }
            }
        }
    }
    func testSamplerRespectsBGRAAndRowPadding() {
        let width=16,height=16,stride=80
        var pixels=[UInt8](repeating:231,count:stride*height)
        for y in 0..<height { for x in 0..<width {
            let i=y*stride+x*4
            pixels[i]=x < 8 ? 0:255; pixels[i+1]=0; pixels[i+2]=x < 8 ? 255:0; pixels[i+3]=255
        } }
        pixels.withUnsafeBufferPointer { p in
            let left=ColorSampler.average(bytes:p.baseAddress!,width:width,height:height,stride:stride,zone:SampleZone(x:0,y:0,width:0.5,height:1))
            let right=ColorSampler.average(bytes:p.baseAddress!,width:width,height:height,stride:stride,zone:SampleZone(x:0.5,y:0,width:0.5,height:1))
            XCTAssertEqual(left,RGB(255,0,0)); XCTAssertEqual(right,RGB(0,0,255))
        }
    }
    func testLetterboxCropAndAllBlackFallback() {
        let w=64,h=100,s=w*4
        var bytes=[UInt8](repeating:0,count:s*h)
        for y in 10..<90 { for x in 0..<w { bytes[y*s+x*4+1]=180 } }
        bytes.withUnsafeBufferPointer { p in
            let crop=ColorSampler.activePicture(bytes:p.baseAddress!,width:w,height:h,stride:s)
            XCTAssertEqual(crop.y,0.1,accuracy:0.001); XCTAssertEqual(crop.height,0.8,accuracy:0.001)
            let color=ColorSampler.average(bytes:p.baseAddress!,width:w,height:h,stride:s,zone:SampleZone(x:0,y:0,width:1,height:1),crop:crop)
            XCTAssertEqual(color,RGB(0,180,0))
        }
        let black=[UInt8](repeating:0,count:s*h)
        black.withUnsafeBufferPointer { p in
            XCTAssertEqual(ColorSampler.activePicture(bytes:p.baseAddress!,width:w,height:h,stride:s),SampleZone(x:0,y:0,width:1,height:1))
        }
    }
    func testSmoothingIndependentOfFrameRate() {
        func run(_ fps: Int) -> RGB {
            var value=RGB.black
            for _ in 0..<fps { value=value.mixed(with:RGB(255,120,30),amount:ColorSampler.smoothingAlpha(delta:1/Double(fps),timeConstant:0.3)) }
            return value
        }
        XCTAssertEqual(run(20).r,run(40).r,accuracy:0.000001)
        XCTAssertEqual(ColorSampler.smoothingAlpha(delta:0.05,timeConstant:0),1)
    }
    func testBrightnessAndBlackFloor() {
        XCTAssertEqual(RGB(4,5,6).adjusted(gain:1,saturation:2,blackThreshold:8),.black)
        XCTAssertEqual(RGB(200,100,50).adjusted(gain:0.5,saturation:1,blackThreshold:0),RGB(100,50,25))
        XCTAssertEqual(RGB(-1,300,.nan).bytes,[0,255,0])
    }
    func testWorkspaceRoundTripPreservesCustomZones() throws {
        var device=DeviceConfig(id:"test",ip:"192.0.2.1",sku:"H606A")
        device.zones=[SampleZone(x:0.33,y:0.2,width:0.1,height:0.1)]
        device.reverse=true
        let saved=SavedWorkspace(devices:[device],settings:StudioSettings(),profiles:[])
        let restored=try JSONDecoder().decode(SavedWorkspace.self,from:JSONEncoder().encode(saved))
        XCTAssertEqual(restored.devices,[device])
    }
}
