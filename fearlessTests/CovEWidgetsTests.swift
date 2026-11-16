@testable import fearless
import UIKit
import XCTest

/// Buttons and compact rows: multiline cards, icon rows, the market button, vertical buttons, copyable rows and
/// checkboxes.
@MainActor
final class CovEWidgetsTests: XCTestCase {
    func testMultilineCardLaysOutFixedAndWrappingModes() {
        let card = MultilineTriangularedView(frame: .zero)
        card.titleLabel.text = "Address"
        card.subtitleLabel.text = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
        let window = CovEHost.window(for: card, frame: CGRect(x: 16, y: 100, width: 358, height: 64))
        defer { CovEHost.close(window) }
        XCTAssertEqual(card.titleLabel.frame.minX, MultilineTriangularedView.Layout.horizontalOffset)
        XCTAssertEqual(card.titleLabel.frame.minY, MultilineTriangularedView.Layout.verticalOffset, accuracy: 0.01)
        XCTAssertEqual(card.backgroundView.frame.size, card.bounds.size)

        let wrapping = MultilineTriangularedView(frame: .zero)
        wrapping.translatesAutoresizingMaskIntoConstraints = false
        wrapping.configureWrapping(locale: Locale(identifier: "en"), compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        wrapping.configureWrapping(locale: Locale(identifier: "en"), compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        XCTAssertEqual(wrapping.titleLabel.numberOfLines, 0)
        XCTAssertEqual(wrapping.subtitleLabel.lineBreakMode, .byCharWrapping)
        wrapping.titleLabel.text = "Title"
        wrapping.subtitleLabel.text = String(repeating: "0x1234", count: 20)
        let size = wrapping.systemLayoutSizeFitting(
            CGSize(width: 300, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel
        )
        XCTAssertGreaterThan(size.height, 60, "Wrapped addresses grow the card")
        let decoded = MultilineTriangularedView(coder: (try? CovEArchive.coder(for: UIView())) ?? NSCoder())
        XCTAssertNotNil(decoded?.titleLabel)
    }

    func testIconRowsPlaceTheIconOnEitherSide() {
        let left = IconTitleValueView(iconPosition: .left)
        let right = IconTitleValueView(iconPosition: .right)
        for row in [left, right] {
            row.imageView.image = R.image.iconInfoFilled()
            row.titleLabel.text = "Rewards"
            row.valueLabel.text = "12%"
        }
        let window = CovEHost.window(for: left, frame: CGRect(x: 16, y: 100, width: 358, height: 40))
        defer { CovEHost.close(window) }
        let second = CovEHost.window(for: right, frame: CGRect(x: 16, y: 200, width: 358, height: 40))
        defer { CovEHost.close(second) }
        XCTAssertLessThan(left.imageView.frame.maxX, left.titleLabel.frame.minX + 0.5, "Left icons precede the title")
        XCTAssertGreaterThan(right.imageView.frame.minX, right.titleLabel.frame.maxX - 0.5, "Right icons follow the title")
        XCTAssertEqual(left.valueLabel.frame.maxX, 358, accuracy: 0.5)
        XCTAssertNotNil(IconTitleValueView(frame: .zero).imageView)
    }

    func testMarketButtonComposesItsTitle() throws {
        let button = MarketButton()
        button.locale = Locale(identifier: "en")
        button.setTitle("smart")
        let label = try XCTUnwrap(CovEFind.all(UILabel.self, in: button).first { $0.attributedText?.string.contains("SMART") == true })
        let market = R.string.localizable.polkaswapMarketStub(preferredLanguages: ["en"])
        XCTAssertEqual(label.attributedText?.string, "\(market): SMART")
        let window = CovEHost.window(for: button, frame: CGRect(x: 16, y: 100, width: 200, height: 40))
        defer { CovEHost.close(window) }
        XCTAssertEqual(button.layer.cornerRadius, 20, accuracy: 0.5, "The button is fully rounded")
    }

    func testVerticalButtonStacksImageOverTitleAndTintsDisabledTitles() {
        let button = VerticalContentButton(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        button.setTitle("Send", for: .normal)
        XCTAssertEqual(button.titleLabel?.textAlignment, .center)
        let withoutImage = button.intrinsicContentSize
        button.setImage(R.image.iconSwipeSend(), for: .normal)
        let window = CovEHost.window(for: button, frame: CGRect(x: 16, y: 100, width: 80, height: 80))
        defer { CovEHost.close(window) }
        let content = button.contentRect(forBounds: button.bounds)
        let image = button.imageRect(forContentRect: content)
        let title = button.titleRect(forContentRect: content)
        XCTAssertLessThan(image.midY, title.minY, "The image sits above the title")
        XCTAssertEqual(image.midX, content.width / 2, accuracy: 0.5)
        XCTAssertEqual(title.width, content.width)
        XCTAssertGreaterThan(button.intrinsicContentSize.height, withoutImage.height)
        button.isEnabled = false
        XCTAssertEqual(button.titleColor(for: .normal), R.color.colorGray())
        button.isEnabled = true
        XCTAssertEqual(button.titleColor(for: .normal), R.color.colorWhite())
        let decoded = VerticalContentButton(coder: (try? CovEArchive.coder(for: UIView())) ?? NSCoder())
        XCTAssertEqual(decoded?.titleLabel?.textAlignment, .center)
    }

    func testCopyableRowAndCheckbox() {
        let row = TitleCopyableValueView(frame: .zero)
        XCTAssertTrue(row.valueImageView.isHidden)
        XCTAssertTrue(row.valueStackView.arrangedSubviews.contains(row.copyButton))
        XCTAssertEqual(row.copyButton.image(for: .normal), R.image.iconCopy())
        let skeletonRow = TitleCopyableValueView(skeletonSize: CGSize(width: 40, height: 10))
        XCTAssertFalse(skeletonRow.valueStackView.arrangedSubviews.contains(skeletonRow.copyButton), "The skeleton initialiser has no copy button")

        let checkbox = CheckboxButton(frame: .zero)
        XCTAssertEqual(checkbox.imageEdgeInsets.left, -UIConstants.bigOffset / 2)
        checkbox.isChecked = true
        XCTAssertEqual(checkbox.image(for: .normal), R.image.iconCheckMark())
        checkbox.buttonClicked(sender: checkbox)
        XCTAssertFalse(checkbox.isChecked)
        XCTAssertEqual(checkbox.image(for: .normal), R.image.iconListSelectionOff())
        checkbox.buttonClicked(sender: UIButton())
        XCTAssertFalse(checkbox.isChecked, "Clicks from other buttons are ignored")
    }
}
