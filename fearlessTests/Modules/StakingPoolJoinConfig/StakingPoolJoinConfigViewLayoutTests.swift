@testable import fearless
import UIKit
import XCTest

/// The Join pool screen labels its fee footer button "Join". The footer relabels its button "Confirm" whenever its own
/// locale changes, so the screen must hand the footer the locale before it sets the title.
@MainActor
final class StakingPoolJoinConfigViewLayoutTests: XCTestCase {
    func testJoinTitle_whenLocaleChanges_thenTheFeeFooterKeepsIt() {
        let layout = StakingPoolJoinConfigViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        for identifier in ["ja", "en", "ru", "en"] {
            let locale = Locale(identifier: identifier)
            layout.locale = locale

            let title = layout.feeView.actionButton.imageWithTitleView?.title
            XCTAssertEqual(
                title,
                R.string.localizable.poolStakingJoinButtonTitle(preferredLanguages: locale.rLanguages),
                identifier
            )
            XCTAssertNotEqual(
                title,
                R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages),
                identifier
            )
        }
    }

    func testJoinTitle_whenTheSameLocaleIsSetAgain_thenItStaysJoin() {
        let layout = StakingPoolJoinConfigViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let locale = Locale(identifier: "ja")

        layout.locale = locale
        layout.locale = locale

        XCTAssertEqual(
            layout.feeView.actionButton.imageWithTitleView?.title,
            R.string.localizable.poolStakingJoinButtonTitle(preferredLanguages: locale.rLanguages)
        )
    }
}
