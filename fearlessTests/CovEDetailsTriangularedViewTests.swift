@testable import fearless
import SoraUI
import UIKit
import XCTest

/// Layout of `DetailsTriangularedView` in each of its layouts, with and without icon and action views, and in the
/// wrapping mode used for large type.
@MainActor
final class CovEDetailsTriangularedViewTests: XCTestCase {
    private let size = CGSize(width: 358, height: 64)
    private let insets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

    func testLargeAndSmallIconLayoutsPlaceIconBeforeLabels() {
        for layout in [DetailsTriangularedView.Layout.largeIconTitleSubtitle, .smallIconTitleSubtitle, .largeIconTitleInfoSubtitle] {
            let view = makeView(layout)
            view.iconRadius = 12
            view.horizontalSpacing = 8
            let window = CovEHost.window(for: view, frame: CGRect(origin: CGPoint(x: 16, y: 100), size: size))
            defer { CovEHost.close(window) }
            XCTAssertEqual(view.actionView.frame, CGRect(x: size.width - size.height, y: 0, width: size.height, height: size.height), "\(layout)")
            XCTAssertEqual(view.iconView.frame.minX, insets.left, "\(layout)")
            XCTAssertEqual(view.iconView.frame.width, 24, "\(layout)")
            let subtitle = view.subtitleLabel
            XCTAssertNotNil(subtitle, "\(layout)")
            XCTAssertGreaterThanOrEqual(subtitle?.frame.minX ?? 0, view.iconView.frame.maxX, "\(layout)")
            XCTAssertLessThanOrEqual(subtitle?.frame.maxX ?? 0, view.actionView.frame.minX + 0.5, "\(layout)")
            XCTAssertGreaterThan(subtitle?.frame.minY ?? 0, view.titleLabel.frame.minY, "\(layout)")
        }
    }

    func testInfoLayoutAddsAnInfoBadgeNextToTheTitle() throws {
        let view = makeView(.largeIconTitleInfoSubtitle)
        let info = try XCTUnwrap(view.additionalInfoView)
        info.setTitle("NEW", for: .normal)
        XCTAssertEqual(info.layer.cornerRadius, DetailsTriangularedView.LayoutConstants.cornerRadius)
        XCTAssertEqual(info.backgroundColor, R.color.colorWhite16())
        let window = CovEHost.window(for: view, frame: CGRect(origin: CGPoint(x: 16, y: 100), size: size))
        defer { CovEHost.close(window) }
        XCTAssertGreaterThanOrEqual(info.frame.minX, view.titleLabel.frame.maxX)
        XCTAssertGreaterThan(info.frame.width, 0)
    }

    func testButtonLayoutsSizeTheActionButtonAndShrinkTheTitle() throws {
        let buttonView = makeView(.smallIconTitleButton)
        XCTAssertNil(buttonView.subtitleLabel, "The button layout drops the subtitle")
        let button = try XCTUnwrap(buttonView.actionButton)
        button.imageWithTitleView?.title = "Edit"
        let window = CovEHost.window(for: buttonView, frame: CGRect(origin: CGPoint(x: 16, y: 100), size: size))
        defer { CovEHost.close(window) }
        XCTAssertEqual(button.frame.size, DetailsTriangularedView.LayoutConstants.actionButtonSize)
        XCTAssertEqual(button.frame.maxX, size.width - insets.right, accuracy: 0.5)
        XCTAssertLessThanOrEqual(buttonView.titleLabel.frame.maxX, button.frame.minX + 0.5)
        XCTAssertEqual(buttonView.titleLabel.frame.minY, DetailsTriangularedView.LayoutConstants.titleVerticalOffset)

        let subtitleButton = makeView(.smallIconTitleSubtitleButton)
        subtitleButton.iconShouldCenterVertically = true
        let actionButton = try XCTUnwrap(subtitleButton.actionButton)
        actionButton.imageWithTitleView?.title = "Claim rewards"
        let second = CovEHost.window(for: subtitleButton, frame: CGRect(origin: CGPoint(x: 16, y: 200), size: size))
        defer { CovEHost.close(second) }
        XCTAssertEqual(actionButton.frame.height, DetailsTriangularedView.LayoutConstants.actionButtonSize.height)
        XCTAssertLessThan(subtitleButton.titleLabel.frame.maxX, actionButton.frame.minX)
        XCTAssertEqual(subtitleButton.subtitleLabel?.numberOfLines, 0)
        XCTAssertEqual(subtitleButton.iconView.frame.midY, subtitleButton.bounds.midY, accuracy: 0.5)
        let expectedHeight = subtitleButton.titleLabel.frame.height + (subtitleButton.subtitleLabel?.frame.height ?? 0) + insets.top + insets.bottom
        XCTAssertEqual(subtitleButton.frame.height, expectedHeight, accuracy: 0.5, "The view resizes to fit both lines")

        subtitleButton.iconShouldCenterVertically = false
        subtitleButton.layoutIfNeeded()
        XCTAssertEqual(subtitleButton.iconView.frame.minY, UIConstants.defaultOffset)
    }

    func testSingleTitleAndWithoutIconLayouts() {
        let single = makeView(.singleTitle)
        XCTAssertNil(single.subtitleLabel)
        let window = CovEHost.window(for: single, frame: CGRect(origin: CGPoint(x: 16, y: 100), size: size))
        defer { CovEHost.close(window) }
        XCTAssertEqual(single.titleLabel.frame.midY, size.height / 2, accuracy: 1)
        XCTAssertGreaterThanOrEqual(single.titleLabel.frame.minX, single.iconView.frame.maxX)

        let plain = makeView(.withoutIcon)
        XCTAssertNil(plain.iconView.superview, "The icon view is removed in the icon-free layout")
        let second = CovEHost.window(for: plain, frame: CGRect(origin: CGPoint(x: 16, y: 200), size: size))
        defer { CovEHost.close(second) }
        XCTAssertEqual(plain.titleLabel.frame.minX, insets.left)
        XCTAssertEqual(plain.titleLabel.frame.maxX, plain.actionView.frame.minX, accuracy: 0.5)
        XCTAssertEqual(plain.subtitleLabel?.frame.maxY ?? 0, size.height - insets.bottom, accuracy: 0.5)

        plain.layout = .singleTitle
        XCTAssertNil(plain.subtitleLabel)
        plain.layout = .smallIconTitleSubtitle
        XCTAssertNotNil(plain.subtitleLabel, "Switching back recreates the subtitle")
    }

    func testWrappingModeGrowsHeightForLongText() throws {
        let view = makeView(.largeIconTitleSubtitle)
        view.translatesAutoresizingMaskIntoConstraints = false
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        view.configureWrapping(locale: Locale(identifier: "en"), compatibleWith: traits, subtitleLines: 1, reservesAction: true)
        XCTAssertEqual(view.titleLabel.numberOfLines, 0)
        XCTAssertEqual(view.subtitleLabel?.numberOfLines, 1)
        XCTAssertEqual(view.subtitleLabel?.lineBreakMode, .byTruncatingMiddle)
        view.titleLabel.text = String(repeating: "Validator commission and identity ", count: 4)
        let container = UIView(frame: CGRect(origin: .zero, size: CovEHost.phoneSize))
        let window = CovEHost.window(for: container, frame: CGRect(origin: .zero, size: CovEHost.phoneSize))
        defer { CovEHost.close(window) }
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 100)
        ])
        container.layoutIfNeeded()
        view.layoutIfNeeded()
        container.layoutIfNeeded()
        let height = try XCTUnwrap(view.constraints.first {
            $0.firstItem === view && $0.firstAttribute == .height && $0.secondItem == nil && type(of: $0) == NSLayoutConstraint.self
        })
        XCTAssertGreaterThan(height.constant, 56, "Long wrapped titles push the row taller than its minimum")
        XCTAssertEqual(view.iconView.frame.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(view.actionView.frame.size, CGSize(width: 24, height: 24))
        XCTAssertEqual(view.subtitleLabel?.frame.minY ?? 0, view.titleLabel.frame.maxY + 8, accuracy: 0.5)

        view.configureWrapping(locale: Locale(identifier: "en"), compatibleWith: traits, subtitleLines: 3)
        XCTAssertEqual(view.subtitleLabel?.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(view.constraints.filter {
            $0.firstItem === view && $0.firstAttribute == .height && $0.secondItem == nil && type(of: $0) == NSLayoutConstraint.self
        }.count, 1)
    }

    func testCopiableActionShowsTheCopyIconAndDecodedViewsConfigure() throws {
        let view = makeView(.largeIconTitleSubtitle)
        view.setupCopiable(for: .subtitle)
        XCTAssertEqual(view.actionView.image, R.image.iconCopy())
        view.setupCopiable(for: .title)
        XCTAssertEqual(view.actionView.image, R.image.iconCopy())

        let decoded = try XCTUnwrap(try DetailsTriangularedView(coder: CovEArchive.coder(for: UIView())))
        decoded.prepareForInterfaceBuilder()
        XCTAssertNotNil(decoded.titleLabel)
        XCTAssertNotNil(decoded.triangularedBackgroundView)
    }

    private func makeView(_ layout: DetailsTriangularedView.Layout) -> DetailsTriangularedView {
        let view = DetailsTriangularedView(frame: .zero)
        view.layout = layout
        view.contentInsets = insets
        view.titleLabel.text = "Polkadot validator"
        view.subtitleLabel?.text = "15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5"
        view.actionView.image = R.image.iconMore()
        if layout != .withoutIcon {
            view.iconView.image = R.image.iconClose()
        }
        return view
    }
}
