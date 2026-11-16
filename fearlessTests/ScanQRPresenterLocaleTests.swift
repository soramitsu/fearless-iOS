import XCTest
import SoraFoundation
@testable import fearless

/// ScanQRPresenter kept the injected localization manager in its own stored property, which does not satisfy
/// Localizable's settable requirement, so `selectedLocale` read Localizable's unset manager and fell back to the
/// device locale: the sheet for an unreadable QR image followed the device language, not the app's.
final class ScanQRPresenterLocaleTests: XCTestCase {
    func testTheUnreadableCodeSheetUsesTheAppLanguage() throws {
        let japanese = try XCTUnwrap(LocalizationManager(localization: "ja"))
        let fixture = CovJUiScanFixture(rawCodes: false, localization: japanese)

        fixture.presenter.handleQRService(error: CovJError("undecodable"))
        XCTAssertTrue(CovJWait.until { fixture.router.sheets.count == 1 })

        let expected = R.string.localizable.commonUndefinedErrorMessage(preferredLanguages: ["ja"])
        XCTAssertNotEqual(expected, R.string.localizable.commonUndefinedErrorMessage(preferredLanguages: ["en"]))
        XCTAssertEqual(fixture.router.sheets.first?.title, expected)
    }

    func testThePresenterFollowsALanguageChange() throws {
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let fixture = CovJUiScanFixture(rawCodes: false, localization: manager)

        manager.selectedLocalization = "ru"

        XCTAssertEqual(fixture.presenter.selectedLocale.identifier, manager.selectedLocale.identifier)
    }
}
