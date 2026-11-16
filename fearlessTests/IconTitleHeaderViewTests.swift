import UIKit
import XCTest
@testable import fearless

/// The validator filter's section headers ask for their own background colour. The header set it as its
/// `backgroundColor`, which UIKit ignores on a header-footer view, so the colour never showed.
final class IconTitleHeaderViewTests: XCTestCase {
    func testCustomBackgroundColorIsShown() throws {
        let header = try makeHeader()
        header.customBackgroundColor = .systemPink

        header.bind(title: "Filter", icon: nil)

        XCTAssertEqual(header.backgroundView?.backgroundColor, .systemPink)
    }

    func testDefaultBackgroundIsBlack() throws {
        let header = try makeHeader()

        header.bind(title: "Filter", icon: nil)

        XCTAssertEqual(header.backgroundView?.backgroundColor, R.color.colorBlack())
    }

    private func makeHeader() throws -> IconTitleHeaderView {
        let nib = UINib(nibName: "IconTitleHeaderView", bundle: Bundle(for: IconTitleHeaderView.self))
        return try XCTUnwrap(nib.instantiate(withOwner: nil).first as? IconTitleHeaderView)
    }
}
