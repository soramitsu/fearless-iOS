import FearlessSecureStorage
import XCTest
@testable import FearlessFoundation

final class LocalizationManagerTests: XCTestCase {
    private let settingsKey = "selectedLocalization"

    func testInit_whenStoredLocalizationExists_thenUsesStoredLocalization() {
        let settings = InMemorySettingsManager()
        settings.set(value: "ja", for: settingsKey)

        let manager = LocalizationManager(
            settings: settings,
            key: settingsKey,
            preferredLanguages: ["fr-CA"],
            availableLocalizations: ["en", "fr", "ja"],
            defaultLocalization: "en"
        )

        XCTAssertEqual(manager.selectedLocalization, "ja")
        XCTAssertEqual(settings.string(for: settingsKey), "ja")
    }

    func testInit_whenNoStoredLocalization_thenSelectsMatchingPreferredLanguageAndPersistsIt() {
        let settings = InMemorySettingsManager()

        let manager = LocalizationManager(
            settings: settings,
            key: settingsKey,
            preferredLanguages: ["fr-CA", "ja-JP"],
            availableLocalizations: ["en", "fr", "ja"],
            defaultLocalization: "en"
        )

        XCTAssertEqual(manager.selectedLocalization, "fr")
        XCTAssertEqual(settings.string(for: settingsKey), "fr")
    }

    func testInit_whenNoPreferredLanguageMatches_thenUsesDefaultLocalization() {
        let settings = InMemorySettingsManager()

        let manager = LocalizationManager(
            settings: settings,
            key: settingsKey,
            preferredLanguages: ["de-DE"],
            availableLocalizations: ["en", "fr", "ja"],
            defaultLocalization: "en"
        )

        XCTAssertEqual(manager.selectedLocalization, "en")
        XCTAssertEqual(settings.string(for: settingsKey), "en")
    }

    func testSelectedLocalization_whenChanged_thenPersistsAndNotifiesObservers() {
        let settings = InMemorySettingsManager()
        let owner = NSObject()
        var events: [String] = []
        let manager = LocalizationManager(
            settings: settings,
            key: settingsKey,
            preferredLanguages: ["en"],
            availableLocalizations: ["en", "ja"],
            defaultLocalization: "en"
        )

        manager.addObserver(with: owner) { oldLocalization, newLocalization in
            events.append("\(oldLocalization)->\(newLocalization)")
        }

        manager.selectedLocalization = "ja"

        XCTAssertEqual(events, ["en->ja"])
        XCTAssertEqual(settings.string(for: settingsKey), "ja")
    }

    func testSelectedLocalization_whenAssignedSameValue_thenDoesNotNotifyObservers() {
        let settings = InMemorySettingsManager()
        let owner = NSObject()
        var events: [String] = []
        let manager = LocalizationManager(
            settings: settings,
            key: settingsKey,
            preferredLanguages: ["en"],
            availableLocalizations: ["en", "ja"],
            defaultLocalization: "en"
        )

        manager.addObserver(with: owner) { oldLocalization, newLocalization in
            events.append("\(oldLocalization)->\(newLocalization)")
        }

        manager.selectedLocalization = "en"

        XCTAssertTrue(events.isEmpty)
    }

    func testRemoveObserver_whenOwnerRemoved_thenStopsNotifications() {
        let settings = InMemorySettingsManager()
        let owner = NSObject()
        var events: [String] = []
        let manager = LocalizationManager(
            settings: settings,
            key: settingsKey,
            preferredLanguages: ["en"],
            availableLocalizations: ["en", "ja"],
            defaultLocalization: "en"
        )

        manager.addObserver(with: owner) { oldLocalization, newLocalization in
            events.append("\(oldLocalization)->\(newLocalization)")
        }
        manager.removeObserver(by: owner)

        manager.selectedLocalization = "ja"

        XCTAssertTrue(events.isEmpty)
    }

    func testInitWithLocalization_whenIdentifierIsValid_thenCreatesManagerAndSelectedLocale() throws {
        let manager = try XCTUnwrap(
            LocalizationManager(localization: "pt_BR", availableLocalizations: ["en", "pt_BR"])
        )

        XCTAssertEqual(manager.selectedLocalization, "pt_BR")
        XCTAssertEqual(manager.availableLocalizations, ["en", "pt_BR"])
        XCTAssertEqual(manager.selectedLocale.identifier, "pt_BR")
    }
}
