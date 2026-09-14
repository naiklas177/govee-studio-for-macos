import XCTest
import AmbienceCore
@testable import GoveeStudio

final class ShowLifecycleTests: XCTestCase {
    func testScenePreviewNeedsNoDisplayAndStopsDeliveringFrames() async throws {
        let engine=CaptureEngine(transport:LANTransport())
        var show=ShowSettings(); show.mode = .scenes
        let received=expectation(description:"Generated frame")
        received.assertForOverFulfill=false
        engine.onFrame={ report in
            XCTAssertNil(report.image)
            XCTAssertEqual(report.colors["test"]?.count,10)
            received.fulfill()
        }
        try await engine.start(display:nil,devices:[DeviceConfig(id:"test",ip:"127.0.0.1",sku:"H606A")],settings:StudioSettings(),output:false,show:show)
        await fulfillment(of:[received],timeout:2)
        await engine.stop()
        let unexpected=expectation(description:"No callback after stop barrier"); unexpected.isInverted=true
        engine.queue.sync { engine.onFrame={_ in unexpected.fulfill()} }
        await fulfillment(of:[unexpected],timeout:0.2)
    }
}
