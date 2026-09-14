import XCTest
import AmbienceCore
@testable import GoveeStudio

final class LocalizationTests: XCTestCase {
    func testLanguageSwitchPreservesSerializedSceneIdentity() throws {
        let settings=ShowSettings()
        let before=try JSONEncoder().encode(settings)
        XCTAssertEqual(LocalizedCopy.translate("Szenen",to:.en),"Scenes")
        XCTAssertEqual(LocalizedCopy.translate("Szenen",to:.de),"Szenen")
        XCTAssertEqual(try JSONDecoder().decode(ShowSettings.self,from:before).scene,settings.scene)
        XCTAssertEqual(LightScene.neon.rawValue,"Neon-Schlat")
    }
    func testStatusTranslationPreservesNumbersAndDoesNotTranslateSubstringsOfNames() {
        XCTAssertEqual(LocalizedCopy.translate("4 Geräte im lokalen Netzwerk.",to:.en),"4 devices on the local network.")
        XCTAssertEqual(LocalizedCopy.translate("BANANA",to:.en),"BANANA")
        XCTAssertEqual(LocalizedCopy.translate("Raum-Farbschema Eigene Farbe",to:.en),"Room color scheme Custom color")
    }
    func testExplicitLanguagePersistsAcrossSettingsInstances() {
        let name="GoveeStudio-LanguageTests-"+UUID().uuidString
        let defaults=UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let settings=LanguageSettings(defaults:defaults)
        settings.language = .en
        XCTAssertEqual(LanguageSettings(defaults:defaults).language,.en)
        settings.language = .de
        XCTAssertEqual(LanguageSettings(defaults:defaults).language,.de)
    }
    func testMajorControlsAndAllSceneDescriptionsHaveEnglishCopy() {
        for label in ["Geräte suchen","Dauerhaft speichern","Originalszenen auf allen Geräten starten","Regler übernehmen","Musik-Empfindlichkeit","Schwarze Filmbalken erkennen"] {
            XCTAssertNotEqual(LocalizedCopy.translate(label,to:.en),label)
        }
        for scene in LightScene.allCases { XCTAssertNotNil(LocalizedCopy.english[scene.subtitle],scene.subtitle) }
        for pattern in MusicPattern.allCases { XCTAssertNotNil(LocalizedCopy.english[pattern.detail],pattern.detail) }
    }
}
