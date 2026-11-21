@testable import fearless
import UIKit
import XCTest

/// Small leftovers: empty-state cells, section headers, alignable controls, the top bar, error input fields,
/// input v2 enable state and the account score view.
@MainActor
final class CovEMiscViewsTests: XCTestCase {
    func testCellsHeadersAndAlignableControl() {
        let cell = EmptyStateViewCell(style: .default, reuseIdentifier: nil)
        XCTAssertTrue(cell.emptyView.superview === cell.contentView)
        XCTAssertEqual(cell.selectionStyle, .none)
        XCTAssertEqual(cell.backgroundColor, .clear)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 200)
        cell.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(cell.emptyView.frame.height, 184)

        let header = CollectionViewSectionHeader(frame: CGRect(x: 0, y: 0, width: 390, height: 40))
        header.label.text = "Assets"
        header.layoutIfNeeded()
        XCTAssertEqual(header.label.font, .h5Title)
        XCTAssertEqual(header.label.frame.minX, UIConstants.hugeOffset)
        XCTAssertEqual(header.label.frame.midY, 20, accuracy: 0.5)

        let control = AlignableContentControl(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        let content = UIView()
        control.contentView = content
        control.contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        control.layoutIfNeeded()
        XCTAssertEqual(content.frame, CGRect(x: 8, y: 4, width: 184, height: 32))
        control.alignment = .none
        content.frame = CGRect(x: 1, y: 1, width: 10, height: 10)
        control.setNeedsLayout()
        control.layoutIfNeeded()
        XCTAssertEqual(content.center.x, control.bounds.midX, accuracy: 0.01)
        XCTAssertEqual(content.center.y, control.bounds.midY, accuracy: 0.01, "Without left alignment the superclass centers the content")
    }

    func testTopBarReplacesItsViews() {
        let bar = BaseTopBar(frame: CGRect(x: 0, y: 0, width: 390, height: 56))
        let first = UILabel()
        let second = UILabel()
        bar.setLeftViews([first])
        bar.setLeftViews([second])
        XCTAssertEqual(bar.leftStackView.arrangedSubviews, [second])
        XCTAssertNil(first.superview, "Replaced views leave the bar")
        bar.setCenterViews([UILabel(), UILabel()])
        XCTAssertEqual(bar.centerStackView.arrangedSubviews.count, 2)
        bar.setCenterViews([])
        XCTAssertTrue(bar.centerStackView.arrangedSubviews.isEmpty)
        let button = UIButton()
        bar.setRightViews([button])
        bar.setRightViews([button])
        XCTAssertEqual(bar.rightStackView.arrangedSubviews, [button])
    }

    func testErrorFieldShowsAndHidesItsMessage() {
        let input = UITextField()
        let field = ErrorPresentableInputField(inputField: input)
        let window = CovEHost.window(for: field, frame: CGRect(x: 16, y: 100, width: 358, height: 80))
        defer { CovEHost.close(window) }
        XCTAssertTrue(field.errorContainer.isHidden)
        XCTAssertNil(ErrorPresentableInputField.State.normal.errorText)
        XCTAssertFalse(ErrorPresentableInputField.State.normal.errorViewVisible)
        field.apply(state: .error(text: "Invalid address"))
        field.layoutIfNeeded()
        XCTAssertEqual(field.errorLabel.text, "Invalid address")
        XCTAssertFalse(field.errorContainer.isHidden)
        XCTAssertGreaterThanOrEqual(field.errorContainer.frame.minY, input.frame.maxY)
        field.apply(state: .normal)
        field.layoutIfNeeded()
        XCTAssertNil(field.errorLabel.text)
        XCTAssertTrue(field.errorContainer.isHidden)
    }

    func testInputV2EnableDisable() {
        let input = CommonInputViewV2()
        input.defaultSetup()
        XCTAssertEqual(input.animatedInputField.textField.returnKeyType, .done)
        XCTAssertEqual(input.animatedInputField.textField.autocorrectionType, .no)
        input.disable()
        XCTAssertFalse(input.isUserInteractionEnabled)
        XCTAssertEqual(input.backgroundView.fillColor, R.color.colorAlmostBlack())
        input.enable()
        XCTAssertTrue(input.isUserInteractionEnabled)
    }
}
