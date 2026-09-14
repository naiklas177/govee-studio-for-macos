import XCTest
@testable import AmbienceCore

final class MusicStyleTests: XCTestCase {
    func testMusicPatternsHaveDifferentSpatialReactionsNotJustColors() {
        var show=ShowSettings(); show.mode = .music; show.background=0; show.intensity=1
        let audio=AudioLevels(bass:0.12,mid:0.06,high:0.025,transient:0.03)
        var shapes:Set<[Int]>=[]
        for pattern in MusicPattern.allCases {
            show.musicPattern=pattern
            let colors=ShowRenderer.colors(count:30,time:1.7,offset:0,settings:show,audio:audio,waveAge:0.4,waveStrength:0.8,beat:MusicBeat(index:2,age:0.1,strength:1))
            let energy=colors.map { max($0.r,$0.g,$0.b) }
            let peak=max(1,energy.max() ?? 1)
            shapes.insert(energy.map { Int(($0/peak*100).rounded()) })
        }
        XCTAssertEqual(shapes.count,MusicPattern.allCases.count)
    }
    func testAllMusicPatternsRespectSilenceIntensityAndBounds() {
        var show=ShowSettings(); show.mode = .music; show.background=0
        for pattern in MusicPattern.allCases {
            show.musicPattern=pattern
            XCTAssertEqual(ShowRenderer.colors(count:30,time:5,offset:0,settings:show),Array(repeating:.black,count:30))
            for palette in MusicColors.allCases {
                show.musicColors=palette; show.intensity=4
                let colors=ShowRenderer.colors(count:84,time:999,offset:0.7,settings:show,audio:AudioLevels(bass:0.4,mid:0.4,high:0.4,transient:0.4),waveAge:0.2,waveStrength:1)
                XCTAssertTrue(colors.allSatisfy { [$0.r,$0.g,$0.b].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 255 } })
                show.intensity=0
                XCTAssertEqual(ShowRenderer.colors(count:30,time:5,offset:0,settings:show,audio:AudioLevels(bass:1,mid:1,high:1)),Array(repeating:.black,count:30))
            }
            show.intensity=1
        }
    }
    func testPaletteInterpolationKeepsChromaAndLoopsWithoutJump() {
        for palette in MusicColors.allCases {
            for i in 0..<30 {
                let color=ShowRenderer.paletteColor(palette.palette,position:Double(i)/30)
                let minimumChroma=palette.palette.map { max($0.r,$0.g,$0.b)-min($0.r,$0.g,$0.b) }.min()!
                XCTAssertGreaterThanOrEqual(max(color.r,color.g,color.b)-min(color.r,color.g,color.b),minimumChroma-0.001)
            }
            XCTAssertEqual(ShowRenderer.paletteColor(palette.palette,position:0),ShowRenderer.paletteColor(palette.palette,position:1))
        }
    }
    func testOnsetTrackerDoesNotInventBeatsDuringSilenceOrSteadyTone() {
        var tracker=MusicBeatTracker()
        XCTAssertEqual(tracker.update(audio:.silent,time:1,sensitivity:1).index,0)
        let hit=tracker.update(audio:AudioLevels(bass:0.15),time:1.1,sensitivity:1)
        XCTAssertEqual(hit.index,1)
        for i in 1...30 { XCTAssertEqual(tracker.update(audio:AudioLevels(bass:0.15),time:1.1+Double(i)*0.04,sensitivity:1).index,1) }
        _=tracker.update(audio:.silent,time:2.4,sensitivity:1)
        XCTAssertEqual(tracker.update(audio:AudioLevels(bass:0.4),time:2.5,sensitivity:1).index,2)
    }
    func testImpulseColorModeChangesOnlyAfterDetectedBeat() throws {
        var show=ShowSettings(); show.mode = .music; show.musicPattern = .spectrum; show.musicColorFlow = .beat
        let audio=AudioLevels(bass:0.1,mid:0.1,high:0.1)
        let a=ShowRenderer.colors(count:12,time:1,offset:0,settings:show,audio:audio,beat:MusicBeat(index:1))
        let b=ShowRenderer.colors(count:12,time:1,offset:0,settings:show,audio:audio,beat:MusicBeat(index:2))
        XCTAssertNotEqual(a,b)
        let saved=try JSONDecoder().decode(ShowSettings.self,from:JSONEncoder().encode(show))
        XCTAssertEqual(saved.musicColorFlow,.beat)
    }
}
