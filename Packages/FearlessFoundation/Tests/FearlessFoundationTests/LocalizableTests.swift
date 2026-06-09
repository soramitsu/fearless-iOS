import XCTest
@testable import FearlessFoundation

final class LocalizableTests: XCTestCase {
    func testLocalizationManager_whenAssigned_thenAppliesLocalizationAndObservesChanges() {
        let view = LocalizableView()
        let manager = LocalizationManager(localization: "en", availableLocalizations: ["en", "ja"])!

        view.localizationManager = manager
        manager.selectedLocalization = "ja"

        XCTAssertEqual(view.applyCount, 2)
        XCTAssertTrue(view.localizationManager === manager)
    }

    func testLocalizationManager_whenReassigned_thenStopsObservingPreviousManager() {
        let view = LocalizableView()
        let firstManager = LocalizationManager(localization: "en", availableLocalizations: ["en", "ja"])!
        let secondManager = LocalizationManager(localization: "en", availableLocalizations: ["en", "fr"])!

        view.localizationManager = firstManager
        view.localizationManager = secondManager
        firstManager.selectedLocalization = "ja"
        secondManager.selectedLocalization = "fr"

        XCTAssertEqual(view.applyCount, 3)
        XCTAssertTrue(view.localizationManager === secondManager)
    }
}

private final class LocalizableView: NSObject, Localizable {
    private(set) var applyCount = 0

    func applyLocalization() {
        applyCount += 1
    }
}
