@testable import fearless
import SoraFoundation
import XCTest

/// Principal class of the unit-test bundle (`NSPrincipalClass` in fearlessTests/Info.plist).
///
/// `LocalizationManager.shared` persists the selected language in the test host's user defaults, so a test
/// that switches it and does not restore it changes every later test, and every later run on that simulator.
/// Each test starts in English, the app's default.
@objc(FearlessTestsPrincipal)
final class FearlessTestsPrincipal: NSObject, XCTestObservation {
    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testCaseWillStart(_: XCTestCase) {
        if LocalizationManager.shared.selectedLocalization != "en" {
            LocalizationManager.shared.selectedLocalization = "en"
        }
    }
}
