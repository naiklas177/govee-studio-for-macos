import XCTest
@testable import AmbienceCore

final class LightShowTests: XCTestCase {
    func testMeteorDirectionMirrorsTheChannelSequence() {
        var show=ShowSettings(); show.scene = .meteor
        let forward=ShowRenderer.colors(count:10,time:1,offset:0,settings:show)
        show.reverseMotion=true
        let reverse=ShowRenderer.colors(count:10,time:1,offset:0,settings:show)
        // Envelope is mirrored; verify the brightest channel moves to the opposite side.
        func brightest(_ colors: [RGB]) -> Int { colors.indices.max { colors[$0].r+colors[$0].g+colors[$0].b < colors[$1].r+colors[$1].g+colors[$1].b }! }
        XCTAssertEqual(brightest(forward),9-brightest(reverse))
    }
    func testBassWaveTriggersOnRiseAndKeepsTravellingAfterImpulse() {
        var tracker=BassWaveTracker()
        XCTAssertNil(tracker.update(bass:0,time:1))
        let onset=tracker.update(bass:0.2,time:1.1)
        XCTAssertEqual(onset?.age,0)
        XCTAssertGreaterThan(onset?.strength ?? 0,0)
        let later=tracker.update(bass:0,time:1.3)
        XCTAssertEqual(later!.age,0.2,accuracy:0.001)
        var show=ShowSettings(); show.mode = .music; show.musicPattern = .wave; show.background=0
        let first=ShowRenderer.colors(count:20,time:1.1,offset:0,settings:show,waveAge:0,waveStrength:1)
        let second=ShowRenderer.colors(count:20,time:1.3,offset:0,settings:show,waveAge:0.6,waveStrength:1)
        XCTAssertNotEqual(first,second)
        XCTAssertTrue(second.contains { $0.r > 0 })
    }
    func testMusicRenderingIsIndependentOfSceneSelection() {
        var show=ShowSettings(); show.mode = .music
        let audio=AudioLevels(bass:0.08,mid:0.04,high:0.03)
        for pattern in MusicPattern.allCases {
            show.musicPattern=pattern
            show.scene = .neon
            let reference=ShowRenderer.colors(count:20,time:1,offset:0,settings:show,audio:audio,waveAge:0.3,waveStrength:1)
            for scene in LightScene.allCases {
                show.scene=scene
                XCTAssertEqual(reference,ShowRenderer.colors(count:20,time:1,offset:0,settings:show,audio:audio,waveAge:0.3,waveStrength:1))
            }
        }
    }
    func testMusicPatternAndPalettePersistSeparatelyFromScene() throws {
        var show=ShowSettings(); show.scene = .ember
        show.musicPattern = .chase; show.musicColors = .ice
        let saved=try JSONDecoder().decode(ShowSettings.self,from:JSONEncoder().encode(show))
        XCTAssertEqual(saved.scene,.ember)
        XCTAssertEqual(saved.musicPattern,.chase)
        XCTAssertEqual(saved.musicColors,.ice)
    }
    func testOldShowSettingsDecodeWithoutLosingExistingPreferences() throws {
        var show=ShowSettings(); show.sensitivity=4.5; show.intensity=0.85
        var json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(show)) as! [String:Any]
        json.removeValue(forKey:"ambilight"); json.removeValue(forKey:"musicColorSaturation")
        let decoded=try JSONDecoder().decode(ShowSettings.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(decoded.sensitivity,4.5)
        XCTAssertEqual(decoded.intensity,0.85)
        XCTAssertFalse(decoded.musicBackground.enabled)
        XCTAssertEqual(decoded.musicSaturation,1)
    }
    func testHybridSilencePreservesScreenAndEffectUsesRemainingHeadroom() {
        let screen=RGB(120,30,210)
        XCTAssertEqual(ShowRenderer.composite(background:screen,effect:.black),screen)
        XCTAssertEqual(ShowRenderer.composite(background:.black,effect:screen),screen)
        let combined=ShowRenderer.composite(background:screen,effect:RGB(255,100,50))
        XCTAssertEqual(combined.r,255)
        XCTAssertGreaterThan(combined.g,screen.g)
        XCTAssertLessThan(combined.g,255)
    }
    func testFourHundredPercentReallyBoostsMusicWithoutChangingBackgroundSettings() {
        var show=ShowSettings(); show.mode = .music; show.intensity=1
        let audio=AudioLevels(bass:0.03,mid:0.03,high:0.03)
        let normal=ShowRenderer.colors(count:10,time:0,offset:0,settings:show,audio:audio)
        show.intensity=4; show.validate()
        XCTAssertEqual(show.intensity,4)
        let boosted=ShowRenderer.colors(count:10,time:0,offset:0,settings:show,audio:audio)
        XCTAssertGreaterThan(boosted.reduce(0){$0+$1.r+$1.g+$1.b},normal.reduce(0){$0+$1.r+$1.g+$1.b})
        XCTAssertEqual(show.background,0.12)
    }
    func testHybridPreferencesRoundTripIndependently() throws {
        var show=ShowSettings(); show.musicBackground.enabled=true
        show.musicBackground.smoothing=1.2; show.decay=0.08
        show.musicBackground.saturation=0.4; show.musicSaturation=1.8
        let decoded=try JSONDecoder().decode(ShowSettings.self,from:JSONEncoder().encode(show))
        XCTAssertEqual(decoded,show)
        XCTAssertEqual(decoded.musicBackground.smoothing,1.2)
        XCTAssertEqual(decoded.decay,0.08)
    }
    func testSilenceLeavesOnlyBackgroundRegardlessOfTimeOrScene() {
        var settings=ShowSettings(); settings.mode = .music
        for scene in LightScene.allCases {
            settings.scene=scene
            let first=ShowRenderer.colors(count:60,time:0,offset:0,settings:settings)
            let later=ShowRenderer.colors(count:60,time:100,offset:0.7,settings:settings)
            XCTAssertEqual(first,later)
            XCTAssertEqual(Set(first.map { $0.bytes }),Set([first[0].bytes]))
        }
        settings.background=0
        XCTAssertEqual(ShowRenderer.colors(count:10,time:2,offset:0,settings:settings),Array(repeating:.black,count:10))
    }
    func testIntensityZeroAndFullBackgroundAreStable() {
        var settings=ShowSettings(); settings.intensity=0
        XCTAssertEqual(ShowRenderer.colors(count:10,time:0,offset:0,settings:settings),ShowRenderer.colors(count:10,time:20,offset:0,settings:settings))
        settings.background=1; settings.intensity=1
        XCTAssertEqual(ShowRenderer.colors(count:10,time:0,offset:0,settings:settings),ShowRenderer.colors(count:10,time:20,offset:0,settings:settings))
    }
    func testAudioCrossoverSeparatesBassMidAndTreble() {
        func analyze(_ frequency: Double) -> AudioLevels {
            var analyzer=AudioAnalyzer()
            return analyzer.process((0..<48000).map { Float(sin(2 * .pi*frequency*Double($0)/48000)*0.4) },sampleRate:48000)
        }
        let bass=analyze(60), mid=analyze(800), high=analyze(9000)
        XCTAssertGreaterThan(bass.bass,bass.mid*2)
        XCTAssertGreaterThan(mid.mid,mid.bass*2)
        XCTAssertGreaterThan(high.high,high.mid*2)
        XCTAssertEqual(bass.level,0.4/sqrt(2),accuracy:0.001)
    }
    func testAudioProducesReactionAndSilenceDecays() {
        var analyzer=AudioAnalyzer()
        _=analyzer.process(Array(repeating:0.4,count:4800),sampleRate:48000)
        let silence=analyzer.process(Array(repeating:0,count:48000),sampleRate:48000)
        XCTAssertEqual(silence.level,0)
        var settings=ShowSettings(); settings.mode = .music
        let quiet=ShowRenderer.colors(count:30,time:2,offset:0,settings:settings)
        let loud=ShowRenderer.colors(count:30,time:2,offset:0,settings:settings,audio:AudioLevels(bass:0.3,mid:0.2,high:0.1,level:0.4,transient:0.1))
        XCTAssertNotEqual(quiet,loud)
    }
    func testChannelOverrideNeverMutatesAmbilightMapping() throws {
        let device=DeviceConfig(id:"hex",ip:"127.0.0.1",sku:"H606A")
        let original=device.zones
        var settings=ShowSettings(); settings.channelCounts[device.id]=60
        let saved=try JSONDecoder().decode(ShowSettings.self,from:JSONEncoder().encode(settings))
        XCTAssertEqual(saved.count(for:device),60)
        XCTAssertEqual(device.zones,original)
        XCTAssertEqual(device.zones.count,10)
    }
    func testAllScenesProduceFiniteBoundedFrames() throws {
        var settings=ShowSettings(); settings.intensity=Double.nan; settings.speed=Double.infinity
        for scene in LightScene.allCases {
            settings.scene=scene
            for time in [0.0,1,1000,Double.nan] {
                let colors=ShowRenderer.colors(count:200,time:time,offset:0,settings:settings)
                XCTAssertEqual(colors.count,84)
                XCTAssertTrue(colors.allSatisfy { [$0.r,$0.g,$0.b].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 255 } })
                XCTAssertNoThrow(try GoveeProtocol.frame(colors,header:.automatic,stretch:false))
            }
        }
    }
}
