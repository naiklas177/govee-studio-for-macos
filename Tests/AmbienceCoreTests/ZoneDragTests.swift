import XCTest
@testable import AmbienceCore

final class ZoneDragTests: XCTestCase {
    private let initial=SampleZone(x:0.2,y:0.25,width:0.1,height:0.2)

    func testMoveTracksAbsoluteCanvasDisplacementWithoutFeedback() {
        let drag=ZoneDragSession(zone:initial,pointerX:140,pointerY:120,canvasWidth:600,canvasHeight:300,operation:.move)
        for step in 0...240 {
            let moved=drag.zone(pointerX:140+Double(step),pointerY:120+Double(step)/4)
            XCTAssertEqual(moved.x,initial.x+Double(step)/600,accuracy:1e-10)
            XCTAssertEqual(moved.y,initial.y+Double(step)/1200,accuracy:1e-10)
            XCTAssertEqual(moved.width,initial.width)
        }
    }
    func testReturningPointerToStartRestoresOrigin() {
        let drag=ZoneDragSession(zone:initial,pointerX:100,pointerY:100,canvasWidth:600,canvasHeight:300,operation:.move)
        _=drag.zone(pointerX:400,pointerY:220)
        XCTAssertEqual(drag.zone(pointerX:100,pointerY:100),initial)
    }
    func testOvershootingAndReturningDoesNotAccumulateBoundaryError() {
        let drag=ZoneDragSession(zone:initial,pointerX:0,pointerY:0,canvasWidth:600,canvasHeight:300,operation:.move)
        let edge=drag.zone(pointerX:2000,pointerY:-2000)
        XCTAssertEqual(edge.x,0.9,accuracy:1e-10); XCTAssertEqual(edge.y,0)
        let back=drag.zone(pointerX:60,pointerY:30)
        XCTAssertEqual(back.x,0.3,accuracy:1e-10); XCTAssertEqual(back.y,0.35,accuracy:1e-10)
    }
    func testResizeKeepsTopLeftFixedAtBothBounds() {
        let drag=ZoneDragSession(zone:initial,pointerX:0,pointerY:0,canvasWidth:600,canvasHeight:300,operation:.resize)
        for point in [-2000.0,0,60,2000] {
            let resized=drag.zone(pointerX:point,pointerY:point)
            XCTAssertEqual(resized.x,initial.x,accuracy:1e-10); XCTAssertEqual(resized.y,initial.y,accuracy:1e-10)
            XCTAssertLessThanOrEqual(resized.x+resized.width,1)
            XCTAssertLessThanOrEqual(resized.y+resized.height,1)
            XCTAssertGreaterThanOrEqual(resized.width,0.015)
            XCTAssertGreaterThanOrEqual(resized.height,0.015)
        }
    }
    func testCroppedCanvasUsesItsOwnPixelSize() {
        let full=ZoneDragSession(zone:initial,pointerX:0,pointerY:0,canvasWidth:600,canvasHeight:300,operation:.move)
        let crop=ZoneDragSession(zone:initial,pointerX:0,pointerY:0,canvasWidth:600,canvasHeight:150,operation:.move)
        XCTAssertEqual(full.zone(pointerX:0,pointerY:30).y,0.35,accuracy:1e-10)
        XCTAssertEqual(crop.zone(pointerX:0,pointerY:30).y,0.45,accuracy:1e-10)
    }
    func testNonFinitePointerCannotPoisonGeometry() {
        let drag=ZoneDragSession(zone:initial,pointerX:0,pointerY:0,canvasWidth:600,canvasHeight:300,operation:.move)
        XCTAssertEqual(drag.zone(pointerX:.nan,pointerY:0),initial)
        XCTAssertEqual(drag.zone(pointerX:0,pointerY:.infinity),initial)
    }
}
