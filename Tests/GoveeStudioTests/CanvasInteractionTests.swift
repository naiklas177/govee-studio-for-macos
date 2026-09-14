import XCTest
import AppKit
import AmbienceCore
@testable import GoveeStudio

/// Detached NSView tests: call responder methods with synthetic NSEvents directly.
/// No events are posted to the OS, no pointer is moved, and no lights/network are used.
@MainActor
final class CanvasInteractionTests: XCTestCase {
    private let zone=SampleZone(x:0.2,y:0.2,width:0.1,height:0.2)
    private let crop=SampleZone(x:0,y:0,width:1,height:1)
    private func event(_ type: NSEvent.EventType,at point: NSPoint,in view: NSView) -> NSEvent {
        NSEvent.mouseEvent(with:type,location:view.convert(point,to:nil),modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    private func canvas() -> ZoneCanvasView { ZoneCanvasView(frame:NSRect(x:0,y:0,width:600,height:300)) }

    func testControlSelectionGroupDragAndToggle() {
        let view=canvas()
        let second=SampleZone(x:0.6,y:0.2,width:0.1,height:0.2)
        var batches:[[Int:SampleZone]]=[]
        func configure() {
            view.configure(deviceID:"multi",zones:[zone,second],selectedIndex:1,crop:crop,tint:.systemMint,
                           onSelect:{_ in},onPreview:{_,_ in},onCommit:{_,_ in XCTFail("Expected batch")},
                           onCommitMany:{batches.append($0)})
        }
        configure()
        let control=NSEvent.mouseEvent(with:.leftMouseDown,location:view.convert(NSPoint(x:150,y:85),to:nil),modifierFlags:.control,timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        view.mouseDown(with:control)
        XCTAssertEqual(view.selection,[0,1])
        view.mouseDown(with:event(.leftMouseDown,at:NSPoint(x:150,y:85),in:view))
        view.mouseDragged(with:event(.leftMouseDragged,at:NSPoint(x:750,y:85),in:view))
        configure()
        view.mouseUp(with:event(.leftMouseUp,at:NSPoint(x:750,y:85),in:view))
        XCTAssertEqual(batches.count,1)
        XCTAssertEqual(batches[0][0]!.x,0.5,accuracy:1e-9)
        XCTAssertEqual(batches[0][1]!.x,0.9,accuracy:1e-9)
        // Both stop at the boundary together: spacing must remain unchanged.
        XCTAssertEqual(batches[0][1]!.x-batches[0][0]!.x,0.4,accuracy:1e-9)
        let toggle=NSEvent.mouseEvent(with:.leftMouseDown,location:view.convert(NSPoint(x:330,y:85),to:nil),modifierFlags:.control,timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        view.mouseDown(with:toggle)
        XCTAssertEqual(view.selection,[1])
    }

    func testMouseDragSurvivesVideoRefreshAndCommitsOnlyOnRelease() {
        let view=canvas()
        var commits:[SampleZone]=[]
        var previews:[SampleZone]=[]
        func configure() {
            view.configure(deviceID:"test",zones:[zone],selectedIndex:0,crop:crop,tint:.systemMint,
                           onSelect:{_ in},onPreview:{z,_ in previews.append(z)},onCommit:{z,_ in commits.append(z)})
        }
        configure()
        view.mouseDown(with:event(.leftMouseDown,at:NSPoint(x:150,y:85),in:view))
        for i in 1...120 {
            view.mouseDragged(with:event(.leftMouseDragged,at:NSPoint(x:150+Double(i),y:85+Double(i)/2),in:view))
            if i%4 == 0 { configure() } // Incoming persisted geometry must not snap the drag back.
            XCTAssertTrue(commits.isEmpty)
        }
        view.mouseUp(with:event(.leftMouseUp,at:NSPoint(x:270,y:145),in:view))
        XCTAssertEqual(commits.count,1)
        XCTAssertEqual(commits[0].x,0.4,accuracy:1e-9)
        XCTAssertEqual(commits[0].y,0.4,accuracy:1e-9)
        XCTAssertEqual(previews.last,commits.first)
        XCTAssertFalse(view.mouseDownCanMoveWindow)
    }
    func testResizeUsesSeparateGripAndKeepsAnchor() {
        let view=canvas()
        var result:SampleZone?
        view.configure(deviceID:"test",zones:[zone],selectedIndex:0,crop:crop,tint:.systemMint,
                       onSelect:{_ in},onPreview:{_,_ in},onCommit:{z,_ in result=z})
        view.mouseDown(with:event(.leftMouseDown,at:NSPoint(x:174,y:114),in:view))
        view.mouseDragged(with:event(.leftMouseDragged,at:NSPoint(x:234,y:144),in:view))
        view.mouseUp(with:event(.leftMouseUp,at:NSPoint(x:234,y:144),in:view))
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.x,zone.x,accuracy:1e-9); XCTAssertEqual(result!.y,zone.y,accuracy:1e-9)
        XCTAssertEqual(result!.width,0.2,accuracy:1e-9); XCTAssertEqual(result!.height,0.3,accuracy:1e-9)
    }
    func testReturnToOriginFlushesLightingPreviewWithoutSaving() {
        let view=canvas()
        var commits=0
        var previews:[SampleZone]=[]
        view.configure(deviceID:"test",zones:[zone],selectedIndex:0,crop:crop,tint:.systemMint,
                       onSelect:{_ in},onPreview:{z,_ in previews.append(z)},onCommit:{_,_ in commits += 1})
        view.mouseDown(with:event(.leftMouseDown,at:NSPoint(x:150,y:85),in:view))
        view.mouseDragged(with:event(.leftMouseDragged,at:NSPoint(x:270,y:145),in:view))
        view.mouseUp(with:event(.leftMouseUp,at:NSPoint(x:150,y:85),in:view))
        XCTAssertEqual(commits,0)
        XCTAssertEqual(previews.last,zone)
    }
    func testSwitchingDeviceCancelsInFlightPreview() {
        let view=canvas()
        var last:SampleZone?
        var commits=0
        view.configure(deviceID:"a",zones:[zone],selectedIndex:0,crop:crop,tint:.systemMint,
                       onSelect:{_ in},onPreview:{z,_ in last=z},onCommit:{_,_ in commits += 1})
        view.mouseDown(with:event(.leftMouseDown,at:NSPoint(x:150,y:85),in:view))
        view.mouseDragged(with:event(.leftMouseDragged,at:NSPoint(x:270,y:145),in:view))
        view.configure(deviceID:"b",zones:[zone],selectedIndex:0,crop:crop,tint:.systemMint,
                       onSelect:{_ in},onPreview:{_,_ in},onCommit:{_,_ in commits += 1})
        view.mouseUp(with:event(.leftMouseUp,at:NSPoint(x:270,y:145),in:view))
        XCTAssertEqual(commits,0)
        XCTAssertEqual(last,zone)
    }
}
