@testable import fearless
import SoraUI
import UIKit
import XCTest

/// Interface Builder inspectable properties of the triangulared controls: every key written through KVC
/// (the way storyboards do) must reach the backing view and read back.
@MainActor
final class CovEInspectableTests: XCTestCase {
    private var image: UIImage {
        let image = R.image.iconClose()
        XCTAssertNotNil(image)
        return image ?? UIImage()
    }

    private var otherImage: UIImage {
        let image = R.image.iconCopy()
        XCTAssertNotNil(image)
        return image ?? UIImage()
    }

    func testAmountInputViewInspectablesReachLabelsFieldAndBackground() {
        let view = AmountInputView(frame: CGRect(x: 0, y: 0, width: 358, height: 90))
        CovEKVC.assertRoundTrip(view, "fillColor", UIColor.red)
        XCTAssertEqual(view.triangularedBackgroundView?.highlightedFillColor, .red)
        CovEKVC.assertRoundTrip(view, "strokeColor", UIColor.blue)
        XCTAssertEqual(view.triangularedBackgroundView?.highlightedStrokeColor, .blue)
        CovEKVC.assertRoundTrip(view, "title", "Amount")
        XCTAssertEqual(view.titleLabel.text, "Amount")
        CovEKVC.assertRoundTrip(view, "titleColor", UIColor.green)
        CovEKVC.assertFont(view, nameKey: "_titleFontName", sizeKey: "_titleFontSize")
        CovEKVC.assertRoundTrip(view, "priceText", "$1.00")
        CovEKVC.assertFont(view, nameKey: "_priceFontName", sizeKey: "_priceFontSize")
        CovEKVC.assertRoundTrip(view, "priceColor", UIColor.orange)
        CovEKVC.assertRoundTrip(view, "balanceText", "Balance: 10")
        CovEKVC.assertFont(view, nameKey: "_balanceFontName", sizeKey: "_balanceFontSize")
        CovEKVC.assertRoundTrip(view, "balanceColor", UIColor.purple)
        CovEKVC.assertRoundTrip(view, "symbol", "DOT")
        CovEKVC.assertFont(view, nameKey: "_symbolFontName", sizeKey: "_symbolFontSize")
        CovEKVC.assertRoundTrip(view, "symbolColor", UIColor.brown)
        CovEKVC.assertRoundTrip(view, "fieldText", "12.5")
        XCTAssertEqual(view.textField.text, "12.5")
        CovEKVC.assertFont(view, nameKey: "_filedFontName", sizeKey: "_fieldFontSize")
        CovEKVC.assertRoundTrip(view, "fieldColor", UIColor.cyan)
        CovEKVC.assertRoundTrip(view, "assetIcon", image)
        CovEKVC.assertRoundTrip(view, "borderWidth", 2.0)
        CovEKVC.assertRoundTrip(view, "_iconRadius", 12.0)
        XCTAssertEqual(view.iconRadius, 12)
        CovEKVC.assertRoundTrip(view, "_horizontalSpacing", 6.0)
        XCTAssertEqual(view.horizontalSpacing, 6)
        CovEKVC.assertRoundTrip(view, "_verticalSpacing", 4.0)
        XCTAssertEqual(view.verticalSpacing, 4)
        CovEKVC.assertRoundTrip(view, "_top", 3.0)
        view.setValue(5.0, forKey: "_left")
        view.setValue(7.0, forKey: "_bottom")
        view.setValue(9.0, forKey: "_right")
        XCTAssertEqual(view.contentInsets, UIEdgeInsets(top: 3, left: 5, bottom: 7, right: 9))
        CovEKVC.assertRoundTrip(view, "_inputIndicatorColor", UIColor.magenta)
        XCTAssertEqual(view.textField.tintColor, .magenta)

        view.setValue(nil, forKey: "_titleFontName")
        XCTAssertNotNil(view.titleLabel.font, "UILabel falls back to the system font when cleared")
    }

    func testAmountInputViewLaysOutRowsWithAndWithoutIconAndFocusesFieldOnTap() throws {
        let view = AmountInputView(frame: .zero)
        view.contentInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        view.titleLabel.text = "Amount"
        view.priceLabel.text = "$12"
        view.symbolLabel.text = "KSM"
        view.balanceLabel.text = "Available: 3"
        view.textField.text = "1.5"
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 110))
        defer { CovEHost.close(window) }
        window.makeKeyAndVisible()

        XCTAssertEqual(view.intrinsicContentSize.width, UIView.noIntrinsicMetric)
        let heightWithoutIcon = view.intrinsicContentSize.height
        XCTAssertGreaterThan(heightWithoutIcon, 16 + 16)
        XCTAssertEqual(view.symbolLabel.frame.minX, 12)
        XCTAssertLessThan(view.titleLabel.frame.maxY, view.symbolLabel.frame.minY)
        XCTAssertGreaterThan(view.balanceLabel.frame.minY, view.symbolLabel.frame.maxY)
        XCTAssertEqual(view.textField.frame.maxX, 358 - 12, accuracy: 0.5)
        XCTAssertEqual(view.priceLabel.frame.maxX, 358 - 12, accuracy: 0.5)

        view.iconView.image = image
        XCTAssertTrue(view.iconView === view.iconView, "The icon view is created once")
        view.iconRadius = 10
        view.horizontalSpacing = 4
        view.verticalSpacing = 6
        view.layoutIfNeeded()
        XCTAssertEqual(view.iconView.frame.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(view.symbolLabel.frame.minX, view.iconView.frame.maxX + 4, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(view.intrinsicContentSize.height, heightWithoutIcon - 4)

        view.sendActions(for: .touchUpInside)
        XCTAssertTrue(view.textField.isFirstResponder)
        view.sendActions(for: .touchUpInside)
        XCTAssertTrue(view.textField.isFirstResponder)
        view.textField.resignFirstResponder()

        let decoded = try XCTUnwrap(try AmountInputView(coder: CovEArchive.coder(for: UIView())))
        XCTAssertNotNil(decoded.textField)
        decoded.prepareForInterfaceBuilder()
        XCTAssertNotNil(decoded.triangularedBackgroundView)
    }

    func testRewardSelectionViewInspectablesSelectionAndSkeleton() throws {
        let view = RewardSelectionView(frame: .zero)
        CovEKVC.assertRoundTrip(view, "fillColor", UIColor.red)
        CovEKVC.assertRoundTrip(view, "highlightedFillColor", UIColor.green)
        CovEKVC.assertRoundTrip(view, "strokeColor", UIColor.blue)
        CovEKVC.assertRoundTrip(view, "highlightedStrokeColor", UIColor.yellow)
        CovEKVC.assertRoundTrip(view, "borderWidth", 1.5)
        CovEKVC.assertRoundTrip(view, "title", "Restake")
        CovEKVC.assertRoundTrip(view, "titleColor", UIColor.white)
        CovEKVC.assertFont(view, nameKey: "_titleFontName", sizeKey: "_titleFontSize")
        CovEKVC.assertRoundTrip(view, "amountTitle", "1.2 DOT")
        CovEKVC.assertFont(view, nameKey: "_amountFontName", sizeKey: "_amountFontSize")
        CovEKVC.assertRoundTrip(view, "amountTitleColor", UIColor.gray)
        CovEKVC.assertRoundTrip(view, "priceTitle", "$7")
        CovEKVC.assertFont(view, nameKey: "_priceFontName", sizeKey: "_priceFontSize")
        CovEKVC.assertRoundTrip(view, "priceColor", UIColor.orange)
        CovEKVC.assertRoundTrip(view, "incomeTitle", "14% APY")
        CovEKVC.assertFont(view, nameKey: "_incomeFontName", sizeKey: "_incomeFontSize")
        CovEKVC.assertRoundTrip(view, "incomeColor", UIColor.cyan)
        CovEKVC.assertRoundTrip(view, "_selectionIcon", image)
        XCTAssertEqual(view.iconView.image, image)

        CovEKVC.assertRoundTrip(view, "privateIsSelected", false)
        XCTAssertTrue(view.iconView.isHidden, "Unselected rows hide the check icon")
        CovEKVC.assertRoundTrip(view, "privateIsSelected", true)
        XCTAssertFalse(view.iconView.isHidden)

        view.contentInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 12)
        view.horizontalSpacing = 6
        view.verticalSpacing = 4
        view.selectionWidth = 40
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 64))
        defer { CovEHost.close(window) }
        XCTAssertEqual(view.iconView.frame, CGRect(x: 0, y: 0, width: 40, height: 64))
        XCTAssertEqual(view.titleLabel.frame.minX, 40, accuracy: 0.01)
        XCTAssertEqual(view.incomeLabel.frame.minX, 40, accuracy: 0.01)
        XCTAssertEqual(view.amountLabel.frame.maxX, 358 - 12, accuracy: 0.5)
        XCTAssertEqual(view.priceLabel.frame.maxY, 64 - 8, accuracy: 0.5)
        XCTAssertEqual(view.intrinsicContentSize.width, UIView.noIntrinsicMetric)
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 20)

        let before = view.subviews.count
        view.startLoadingIfNeeded()
        XCTAssertEqual(view.titleLabel.alpha, 0)
        XCTAssertEqual(view.amountLabel.alpha, 0)
        XCTAssertEqual(view.subviews.count, before + 1, "Loading inserts one skeleton view")
        view.startLoadingIfNeeded()
        XCTAssertEqual(view.subviews.count, before + 1, "A second start keeps the same skeleton")
        view.didAppearSkeleton()
        view.didUpdateSkeletonLayout()
        XCTAssertEqual(view.subviews.count, before + 1)
        view.frame.size.width = 300
        view.didUpdateSkeletonLayout()
        XCTAssertEqual(view.subviews.count, before + 1, "A resized skeleton is rebuilt, not duplicated")
        view.didDisappearSkeleton()
        view.stopLoadingIfNeeded()
        XCTAssertEqual(view.subviews.count, before)
        XCTAssertEqual(view.priceLabel.alpha, 1)
        XCTAssertEqual(view.incomeLabel.alpha, 1)
        view.stopLoadingIfNeeded()
        XCTAssertEqual(view.subviews.count, before)

        let hidden = RewardSelectionView(frame: .zero)
        hidden.startLoadingIfNeeded()
        XCTAssertEqual(hidden.titleLabel.alpha, 0, "A zero-sized view still enters the loading state")
        hidden.didUpdateSkeletonLayout()
        hidden.stopLoadingIfNeeded()
        XCTAssertEqual(hidden.titleLabel.alpha, 1)

        let decoded = try XCTUnwrap(try RewardSelectionView(coder: CovEArchive.coder(for: UIView())))
        decoded.prepareForInterfaceBuilder()
        XCTAssertNotNil(decoded.triangularedBackgroundView)
    }

    func testDetailsTriangularedViewInspectablesAndLayoutCodes() {
        let view = DetailsTriangularedView(frame: .zero)
        CovEKVC.assertRoundTrip(view, "backgroundSideLength", 6.0)
        CovEKVC.assertRoundTrip(view, "fillColor", UIColor.red)
        CovEKVC.assertRoundTrip(view, "highlightedFillColor", UIColor.green)
        CovEKVC.assertRoundTrip(view, "strokeColor", UIColor.blue)
        CovEKVC.assertRoundTrip(view, "highlightedStrokeColor", UIColor.yellow)
        CovEKVC.assertRoundTrip(view, "title", "Validator")
        CovEKVC.assertRoundTrip(view, "subtitle", "5Grw...utQY")
        CovEKVC.assertRoundTrip(view, "titleColor", UIColor.white)
        CovEKVC.assertRoundTrip(view, "highlightedTitleColor", UIColor.gray)
        CovEKVC.assertRoundTrip(view, "subtitleColor", UIColor.lightGray)
        CovEKVC.assertRoundTrip(view, "highlightedSubtitleColor", UIColor.darkGray)
        CovEKVC.assertFont(view, nameKey: "_titleFontName", sizeKey: "_titleFontSize")
        CovEKVC.assertFont(view, nameKey: "_subtitleFontName", sizeKey: "_subtitleFontSize")
        CovEKVC.assertRoundTrip(view, "iconImage", image)
        CovEKVC.assertRoundTrip(view, "actionImage", otherImage)
        CovEKVC.assertRoundTrip(view, "actionTintColor", UIColor.orange)
        CovEKVC.assertRoundTrip(view, "borderWidth", 2.0)
        CovEKVC.assertRoundTrip(view, "_iconRadius", 10.0)
        XCTAssertEqual(view.iconRadius, 10)
        CovEKVC.assertRoundTrip(view, "_horizontalSpacing", 5.0)
        XCTAssertEqual(view.horizontalSpacing, 5)

        let expectedLayouts: [(UInt8, DetailsTriangularedView.Layout, UInt8)] = [
            (0, .largeIconTitleSubtitle, 0),
            (1, .smallIconTitleSubtitle, 1),
            (2, .singleTitle, 2),
            (3, .smallIconTitleButton, 3),
            (4, .largeIconTitleInfoSubtitle, 4),
            (6, .withoutIcon, 6),
            (9, .singleTitle, 2)
        ]
        for (code, layout, readBack) in expectedLayouts {
            view.setValue(NSNumber(value: code), forKey: "privateLayout")
            XCTAssertEqual(view.layout, layout, "code \(code)")
            XCTAssertEqual((view.value(forKey: "privateLayout") as? NSNumber)?.uint8Value, readBack)
        }
        view.setValue(NSNumber(value: UInt8(5)), forKey: "privateLayout")
        XCTAssertEqual(view.layout, .smallIconTitleSubtitleButton)
    }

    func testTriangularedButtonInspectablesReachContentAndBackground() {
        let button = TriangularedButton(frame: CGRect(x: 0, y: 0, width: 200, height: 48))
        CovEKVC.assertRoundTrip(button, "_fillColor", UIColor.red)
        CovEKVC.assertRoundTrip(button, "_highlightedFillColor", UIColor.green)
        CovEKVC.assertRoundTrip(button, "_strokeColor", UIColor.blue)
        CovEKVC.assertRoundTrip(button, "_highlightedStrokeColor", UIColor.yellow)
        CovEKVC.assertRoundTrip(button, "_strokeWidth", 1.5)
        CovEKVC.assertRoundTrip(button, "_layoutType", NSNumber(value: UInt8(1)))
        CovEKVC.assertRoundTrip(button, "_title", "Continue")
        XCTAssertEqual(button.imageWithTitleView?.title, "Continue")
        CovEKVC.assertRoundTrip(button, "_titleColor", UIColor.white)
        CovEKVC.assertRoundTrip(button, "_highlightedTitleColor", UIColor.gray)
        CovEKVC.assertRoundTrip(button, "_iconImage", image)
        CovEKVC.assertRoundTrip(button, "_highlightedIconImage", otherImage)
        CovEKVC.assertRoundTrip(button, "_iconTintColor", UIColor.orange)
        CovEKVC.assertFont(button, nameKey: "_titleFontName", sizeKey: "_titleFontSize")
        CovEKVC.assertRoundTrip(button, "_shadowColor", UIColor.black)
        CovEKVC.assertRoundTrip(button, "_shadowOffset", NSValue(cgSize: CGSize(width: 1, height: 2)))
        CovEKVC.assertRoundTrip(button, "_shadowRadius", 3.0)
        CovEKVC.assertRoundTrip(button, "_shadowOpacity", NSNumber(value: Float(0.25)))
        CovEKVC.assertRoundTrip(button, "_sideLength", 7.0)
        CovEKVC.assertRoundTrip(button, "_spacingBetweenItems", 4.0)
        CovEKVC.assertRoundTrip(button, "_contentOpacityWhenHighlighted", 0.5)
        CovEKVC.assertRoundTrip(button, "_contentOpacityWhenDisabled", 0.25)
        CovEKVC.assertRoundTrip(button, "_changesContentOpacityWhenHighlighted", true)
        CovEKVC.assertRoundTrip(button, "_displacementBetweenLabelAndIcon", 3.0)
        CovEKVC.assertRoundTrip(button, "_cornerCut", NSNumber(value: UInt8(5)))
    }

    func testTriangularedBlurButtonAndViewInspectables() throws {
        let button = TriangularedBlurButton(frame: CGRect(x: 0, y: 0, width: 200, height: 48))
        XCTAssertNotNil(button.imageWithTitleView)
        XCTAssertNotNil(button.triangularedBlurView)
        XCTAssertEqual(button.backgroundColor, .clear)
        XCTAssertFalse(button.triangularedBlurView?.isUserInteractionEnabled ?? true)
        CovEKVC.assertRoundTrip(button, "_layoutType", NSNumber(value: UInt8(1)))
        CovEKVC.assertRoundTrip(button, "_title", "Blur")
        CovEKVC.assertRoundTrip(button, "_titleColor", UIColor.white)
        CovEKVC.assertRoundTrip(button, "_highlightedTitleColor", UIColor.gray)
        CovEKVC.assertRoundTrip(button, "_iconImage", image)
        CovEKVC.assertRoundTrip(button, "_highlightedIconImage", otherImage)
        CovEKVC.assertRoundTrip(button, "_iconTintColor", UIColor.orange)
        CovEKVC.assertFont(button, nameKey: "_titleFontName", sizeKey: "_titleFontSize")
        CovEKVC.assertRoundTrip(button, "_spacingBetweenItems", 4.0)
        CovEKVC.assertRoundTrip(button, "_contentOpacityWhenHighlighted", 0.5)
        CovEKVC.assertRoundTrip(button, "_contentOpacityWhenDisabled", 0.25)
        CovEKVC.assertRoundTrip(button, "_changesContentOpacityWhenHighlighted", true)
        CovEKVC.assertRoundTrip(button, "_displacementBetweenLabelAndIcon", 3.0)
        CovEKVC.assertRoundTrip(button, "_cornerCut", NSNumber(value: UInt8(3)))
        CovEKVC.assertRoundTrip(button, "_blurStyle", UIBlurEffect.Style.dark.rawValue)
        CovEKVC.assertRoundTrip(button, "_overlayFillColor", UIColor.black)

        let decoded = try XCTUnwrap(try TriangularedBlurButton(coder: CovEArchive.coder(for: UIView())))
        decoded.prepareForInterfaceBuilder()
        XCTAssertNotNil(decoded.imageWithTitleView)

        let blur = TriangularedBlurView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        CovEKVC.assertRoundTrip(blur, "_cornerCut", NSNumber(value: UInt8(2)))
        CovEKVC.assertRoundTrip(blur, "_blurStyle", UIBlurEffect.Style.light.rawValue)
        CovEKVC.assertRoundTrip(blur, "_overlayFillColor", UIColor.red)
    }

    func testExpandableAndBorderedActionInspectables() {
        let control = ExpandableActionControl(frame: CGRect(x: 0, y: 0, width: 300, height: 48))
        CovEKVC.assertRoundTrip(control, "_title", "Advanced")
        CovEKVC.assertRoundTrip(control, "_titleColor", UIColor.white)
        CovEKVC.assertRoundTrip(control, "_horizontalSpacing", 6.0)
        CovEKVC.assertRoundTrip(control, "_verticalDisplacement", 2.0)
        CovEKVC.assertRoundTrip(control, "_strokeColor", UIColor.red)
        CovEKVC.assertRoundTrip(control, "_strokeWidth", 1.5)
        CovEKVC.assertFont(control, nameKey: "_titleFontName", sizeKey: "_titleFontSize")
        CovEKVC.assertRoundTrip(control, "_minimumFontScale", 0.5)
        CovEKVC.assertRoundTrip(control, "_adjustsFontSizeToFitWidth", true)
        CovEKVC.assertRoundTrip(control, "_layoutType", NSNumber(value: UInt(1)))
        control.setValue(nil, forKey: "_titleFontName")
        XCTAssertNotNil(control.titleLabel.font, "Clearing the font name falls back to the label default")

        let bordered = BorderedSubtitleActionView(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
        CovEKVC.assertRoundTrip(bordered, "_title", "Rewards")
        CovEKVC.assertRoundTrip(bordered, "_titleColor", UIColor.white)
        CovEKVC.assertFont(bordered, nameKey: "_titleFontName", sizeKey: "_titleFontSize")
        CovEKVC.assertRoundTrip(bordered, "privateSubtitle", "Restake")
        CovEKVC.assertRoundTrip(bordered, "privateSubtitleColor", UIColor.gray)
        CovEKVC.assertFont(bordered, nameKey: "_subtitleFontName", sizeKey: "_subtitleFontSize")
        CovEKVC.assertRoundTrip(bordered, "_subtitleIcon", image)
        CovEKVC.assertRoundTrip(bordered, "_indicatorIcon", otherImage)
        CovEKVC.assertRoundTrip(bordered, "_layoutType", NSNumber(value: UInt(1)))
        bordered.setValue(NSNumber(value: UInt(99)), forKey: "_layoutType")
        XCTAssertEqual((bordered.value(forKey: "_layoutType") as? NSNumber)?.uintValue, 1, "Unknown layout codes are ignored")
        bordered.setValue(nil, forKey: "_titleFontName")
        bordered.setValue(nil, forKey: "_subtitleFontName")
        XCTAssertNotNil(bordered.actionControl.contentView.titleLabel.font)

        bordered.disable()
        XCTAssertFalse(bordered.actionControl.isUserInteractionEnabled)
        XCTAssertTrue(bordered.actionControl.imageIndicator.isHidden)
        bordered.enable()
        XCTAssertTrue(bordered.actionControl.isUserInteractionEnabled)
        XCTAssertFalse(bordered.actionControl.imageIndicator.isHidden)
    }
}

/// Builds an `NSCoder` for exercising `init(coder:)` initialisers of views.
enum CovEArchive {
    static func coder(for view: UIView) throws -> NSCoder {
        let data = try NSKeyedArchiver.archivedData(withRootObject: view, requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        return unarchiver
    }
}
