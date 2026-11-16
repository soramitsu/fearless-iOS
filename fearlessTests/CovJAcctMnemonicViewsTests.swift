import XCTest
import UIKit
@testable import fearless

final class CovJAcctMnemonicViewsTests: XCTestCase {
    private let words = CovJAcctImportHarness.phrase.components(separatedBy: " ")

    private func emptyCoder() throws -> NSKeyedUnarchiver {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        return unarchiver
    }

    func testColumnStylingIsAppliedToEveryColumn() throws {
        let view = MnemonicDisplayView()
        view.bind(words: words, columnsCount: 2)
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }

        view.columnsSpacing = 30
        view.horizontalSpacingInColumn = 6
        view.verticalSpacingInColumn = 9
        view.indexTitleColorInColumn = .red
        view.indexFontInColumn = .systemFont(ofSize: 11)
        view.wordTitleColorInColumn = .blue
        view.wordFontInColumn = .systemFont(ofSize: 15)

        XCTAssertEqual(view.columnsSpacing, 30)
        XCTAssertEqual(view.horizontalSpacingInColumn, 6)
        XCTAssertEqual(view.verticalSpacingInColumn, 9)
        XCTAssertEqual(view.indexTitleColorInColumn, .red)
        XCTAssertEqual(view.indexFontInColumn.pointSize, 11)
        XCTAssertEqual(view.wordTitleColorInColumn, .blue)
        XCTAssertEqual(view.wordFontInColumn.pointSize, 15)
        XCTAssertGreaterThan(view.intrinsicContentSize.width, 30)
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 0)

        let labels = CovJViewFixture.descendants(UILabel.self, in: view)
        XCTAssertTrue(labels.contains { $0.text == words[0] && $0.textColor == .blue })
        XCTAssertTrue(labels.contains { $0.text == words[11] })
    }

    func testCoderInitializersConfigureViews() throws {
        let display = try XCTUnwrap(MnemonicDisplayView(coder: try emptyCoder()))
        display.bind(words: words, columnsCount: 3)
        XCTAssertEqual(CovJViewFixture.descendants(UILabel.self, in: display).filter { $0.text == words[5] }.count, 1)

        let button = try XCTUnwrap(AccountConfirmWordButton(coder: try emptyCoder()))
        let labels = CovJViewFixture.descendants(UILabel.self, in: button)
        XCTAssertTrue(labels.contains { $0.numberOfLines == 0 && $0.lineBreakMode == .byCharWrapping && !$0.isUserInteractionEnabled })
        XCTAssertTrue(button.isAccessibilityElement)
        XCTAssertEqual(button.accessibilityTraits, .button)
    }
}
