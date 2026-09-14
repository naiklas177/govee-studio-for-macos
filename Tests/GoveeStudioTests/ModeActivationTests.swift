import XCTest
import AmbienceCore
@testable import GoveeStudio

@MainActor
final class ModeActivationTests: XCTestCase {
    func testRapidRequestsOnlyStartLatestModeAfterRestoration() async {
        let queue=ModeActivationQueue<ExperienceMode>()
        var events:[String]=[]
        queue.stopCurrent={ events.append("stop"); try? await Task.sleep(nanoseconds:30_000_000); events.append("restored") }
        queue.start={ mode in events.append(mode.rawValue) }
        queue.request(.scenes)
        try? await Task.sleep(nanoseconds:5_000_000)
        queue.request(.ambience); queue.request(.music)
        try? await Task.sleep(nanoseconds:80_000_000)
        XCTAssertEqual(events,["stop","restored","Musik"])
    }
    func testStopDuringTransitionNeverStartsPendingOutput() async {
        let queue=ModeActivationQueue<ExperienceMode>()
        var started=false
        queue.stopCurrent={ try? await Task.sleep(nanoseconds:30_000_000) }
        queue.start={ _ in started=true }
        queue.request(.music)
        await queue.cancelAndWait()
        XCTAssertFalse(started)
    }
    func testRequestDuringStartupWaitsBeforeNextStart() async {
        let queue=ModeActivationQueue<ExperienceMode>()
        var events:[String]=[]
        queue.stopCurrent={ events.append("stop") }
        queue.start={ mode in events.append("start-"+mode.rawValue); try? await Task.sleep(nanoseconds:30_000_000); events.append("ready-"+mode.rawValue) }
        queue.request(.scenes)
        try? await Task.sleep(nanoseconds:10_000_000)
        queue.request(.music)
        try? await Task.sleep(nanoseconds:100_000_000)
        XCTAssertEqual(events,["stop","start-Szenen","ready-Szenen","stop","start-Musik","ready-Musik"])
    }
}
