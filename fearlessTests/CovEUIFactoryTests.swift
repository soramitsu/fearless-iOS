@testable import fearless
import SoraUI
import SwiftUI
import UIKit
import XCTest

/// `UIFactory` builders and the stack helpers from `Stacks.swift`.
@MainActor
final class CovEUIFactoryTests: XCTestCase {
    private let factory = UIFactory.default
    private let locale = Locale(identifier: "en")

    func testStacksSeparatorsAndButtons() {
        let vertical = factory.createVerticalStackView(spacing: 6)
        XCTAssertEqual(vertical.axis, .vertical)
        XCTAssertEqual(vertical.spacing, 6)
        let horizontal = factory.createHorizontalStackView(spacing: 3)
        XCTAssertEqual(horizontal.axis, .horizontal)
        XCTAssertEqual(horizontal.spacing, 3)
        XCTAssertEqual(factory.createSeparatorView().backgroundColor, R.color.colorDarkGray())
        let bordered = factory.createBorderedContainerView()
        XCTAssertEqual(bordered.borderType, .bottom)
        XCTAssertEqual(bordered.strokeColor, R.color.colorDarkGray())

        let main = factory.createMainActionButton()
        XCTAssertTrue(main.constraints.contains { $0.firstAttribute == .height && $0.constant == UIConstants.actionHeight })
        XCTAssertNotNil(factory.createAccessoryButton().triangularedView)
        XCTAssertNotNil(factory.createDestructiveButton().triangularedView)
        XCTAssertNotNil(factory.createDisabledButton().triangularedView)
        let rounded = factory.createRoundedButton()
        XCTAssertEqual(rounded.layer.cornerRadius, 12)
        XCTAssertEqual(rounded.titleLabel?.font, .h6Title)
        let title = factory.createTitleLabel()
        XCTAssertEqual(title.numberOfLines, 0)
        XCTAssertEqual(title.font, .p1Paragraph)
        let referral = factory.createWalletReferralBonusButton()
        XCTAssertEqual(referral.gradientBackgroundView?.cornerRadius, UIConstants.referralBonusButtonHeight / 2)
        let indicator = factory.createIndicatorView()
        XCTAssertEqual(indicator.cornerRadius, UIConstants.indicatorSize.height / 2)
        XCTAssertEqual(indicator.shadowOpacity, 0)
        let options = factory.createChainOptionsView()
        XCTAssertEqual(options.distribution, .fillProportionally)
        XCTAssertEqual(options.spacing, UIConstants.defaultOffset)
    }

    func testDetailsViewsForEveryLayoutAndMode() {
        let layouts: [DetailsTriangularedView.Layout] = [
            .singleTitle, .largeIconTitleSubtitle, .smallIconTitleSubtitle, .smallIconTitleButton,
            .largeIconTitleInfoSubtitle, .smallIconTitleSubtitleButton, .withoutIcon
        ]
        for layout in layouts {
            for filled in [true, false] {
                let view = factory.createDetailsView(with: layout, filled: filled)
                XCTAssertEqual(view.layout, layout)
                XCTAssertEqual(view.fillColor, filled ? R.color.colorSemiBlack() : .clear)
                XCTAssertEqual(view.contentInsets, UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
                switch layout {
                case .largeIconTitleSubtitle, .singleTitle, .largeIconTitleInfoSubtitle:
                    XCTAssertEqual(view.iconRadius, UIConstants.triangularedIconLargeRadius)
                case .smallIconTitleSubtitle, .smallIconTitleButton, .smallIconTitleSubtitleButton:
                    XCTAssertEqual(view.iconRadius, UIConstants.triangularedIconSmallRadius)
                case .withoutIcon:
                    XCTAssertNil(view.iconView.superview)
                }
            }
        }
        XCTAssertEqual(factory.createAccountView(for: .options, filled: true).actionView.image, R.image.iconMore())
        XCTAssertEqual(factory.createAccountView(for: .selection, filled: false).actionView.image, R.image.iconExpandable())
        XCTAssertNil(factory.createAccountView(for: .none, filled: false).actionView.image)
        XCTAssertEqual(factory.createAccountView().actionView.image, R.image.iconMore())

        let single = factory.createIdentityView(isSingleTitle: true)
        XCTAssertEqual(single.layout, .singleTitle)
        XCTAssertNil(single.subtitleLabel)
        XCTAssertEqual(single.titleLabel.lineBreakMode, .byTruncatingMiddle)
        let double = factory.createIdentityView(isSingleTitle: false)
        XCTAssertEqual(double.layout, .largeIconTitleSubtitle)
        XCTAssertEqual(double.subtitleLabel?.lineBreakMode, .byTruncatingMiddle)
        XCTAssertEqual(double.contentInsets.left, 11)

        let asset = factory.createChainAssetSelectionView(layout: .smallIconTitleSubtitle)
        XCTAssertEqual(asset.actionView.image, R.image.iconHorMore())
        XCTAssertEqual(asset.iconRadius, 16)
        XCTAssertEqual(factory.createNetworkView(selectable: true).actionView.image, R.image.iconExpandable())
        XCTAssertNil(factory.createNetworkView(selectable: false).actionView.image)
    }

    func testInputAndInformationViews() {
        let mnemonic = factory.createTitledMnemonicView("Words", icon: R.image.iconClose())
        XCTAssertEqual(mnemonic.titleLabel.text, "Words")
        XCTAssertEqual(mnemonic.iconView.image, R.image.iconClose())
        let bareMnemonic = factory.createTitledMnemonicView(nil, icon: nil)
        XCTAssertNil(bareMnemonic.iconView.image)
        let multiline = factory.createMultilinedTriangularedView()
        XCTAssertEqual(multiline.backgroundView.fillColor, R.color.colorDarkGray())
        XCTAssertEqual(multiline.titleLabel.font, .p2Paragraph)
        let expandable = factory.createExpandableActionControl()
        XCTAssertEqual(expandable.layoutType, .flexible)
        XCTAssertEqual(expandable.plusIndicator.strokeColor, R.color.colorWhite())

        for filled in [true, false] {
            let amount = factory.createAmountInputView(filled: filled)
            XCTAssertEqual(amount.triangularedBackgroundView?.strokeWidth, filled ? 0 : 1)
            XCTAssertEqual(amount.textField.keyboardType, .decimalPad)
            XCTAssertEqual(amount.textField.attributedPlaceholder?.string, "0")
            XCTAssertEqual(amount.iconRadius, 12)
        }
        XCTAssertNotNil(factory.createCommonInputView())
        let search = factory.createSearchTextField()
        XCTAssertEqual(search.textField.autocorrectionType, .no)
        XCTAssertEqual(search.triangularedView?.cornerCut, [.bottomRight, .topLeft])
        let infoBackground = factory.createInfoBackground()
        XCTAssertEqual(infoBackground.strokeWidth, 0.5)

        let multi = factory.createMultiView()
        XCTAssertEqual(multi.valueTop.font, .h6Title)
        XCTAssertEqual(multi.borderView.borderType, .none)
        let confirmation = factory.createConfirmationMultiView()
        XCTAssertEqual(confirmation.valueTop.font, .h5Title)
        XCTAssertEqual(confirmation.valueBottom.font, .p1Paragraph)

        XCTAssertNotNil(factory.createNetworkFeeView())
        XCTAssertNotNil(factory.createNetworkFeeFooterView())
        let cleanFooter = factory.createCleanNetworkFeeFooterView()
        XCTAssertNil(cleanFooter.networkFeeView, "Fee and duration rows are created lazily on first bind")
        XCTAssertNil(cleanFooter.durationView)
        XCTAssertNotNil(factory.createTitleValueView())
        XCTAssertNotNil(factory.createIconTitleValueView(iconPosition: .right))
        XCTAssertNotNil(factory.createTitleValueSelectionView())
        XCTAssertNotNil(factory.createHintView())
        XCTAssertEqual(factory.createLearnMoreView().contentInsets.left, UIConstants.horizontalInset)
        XCTAssertEqual(factory.createFearlessLearnMoreView().iconView.image, R.image.iconFearlessSmall())
        let reward = factory.createRewardSelectionView()
        XCTAssertTrue(reward.iconView.isHidden)
        XCTAssertEqual(reward.iconView.image, R.image.listCheckmarkIcon())
        let info = factory.createInfoIndicatingView()
        XCTAssertEqual(info.iconImageView.image, R.image.iconInfoFilled())

        let warning = factory.createWarningView(title: "t", text: "x")
        let stack = try? XCTUnwrap(warning as? UIStackView)
        XCTAssertEqual(stack?.axis, .horizontal)
        XCTAssertEqual(stack?.arrangedSubviews.count, 2)
        XCTAssertEqual(CovEFind.all(UILabel.self, in: warning).map(\.font), [.h6Title, .p3Paragraph])
    }

    func testAccessoryToolbarsForwardEveryActionToTheDelegate() throws {
        let delegate = CovEAccessoryDelegate()
        let amount = try XCTUnwrap(factory.createAmountAccessoryView(for: delegate, locale: locale) as? AmountInputAccessoryView)
        let amountItems = try XCTUnwrap(amount.items)
        let titled = amountItems.filter { $0.title != nil }
        XCTAssertEqual(titled.map(\.title), [
            R.string.localizable.commonMax(preferredLanguages: locale.rLanguages).uppercased(), "75%", "50%", "25%",
            R.string.localizable.commonDone(preferredLanguages: locale.rLanguages)
        ])
        XCTAssertFalse(amount.isTranslucent)
        for item in titled {
            XCTAssertTrue(UIApplication.shared.sendAction(item.action ?? #selector(UIView.layoutIfNeeded), to: item.target, from: item, for: nil))
        }
        XCTAssertEqual(delegate.percentages, [1.0, 0.75, 0.5, 0.25])
        XCTAssertEqual(delegate.dones, 1)

        let slider = try XCTUnwrap(factory.createSliderAccessoryView(for: delegate, locale: locale) as? AmountInputAccessoryView)
        let sliderItems = try XCTUnwrap(slider.items).filter { $0.title != nil }
        XCTAssertEqual(sliderItems.map(\.title), ["0.1%", "0.5%", "1%", R.string.localizable.commonDone(preferredLanguages: locale.rLanguages)])
        for item in sliderItems {
            XCTAssertTrue(UIApplication.shared.sendAction(item.action ?? #selector(UIView.layoutIfNeeded), to: item.target, from: item, for: nil))
        }
        XCTAssertEqual(delegate.percentages, [1.0, 0.75, 0.5, 0.25, 0.1, 0.5, 1.0])
        XCTAssertEqual(delegate.dones, 2)

        let done = try XCTUnwrap(factory.createDoneAccessoryView(for: delegate, locale: locale) as? AmountInputAccessoryView)
        XCTAssertEqual(done.items?.compactMap(\.title), [R.string.localizable.commonDone(preferredLanguages: locale.rLanguages)])
        XCTAssertEqual(done.items?.count, 2, "Only the flexible space and Done remain")

        let plain = factory.createActionsAccessoryView(
            for: [], doneAction: ViewSelectorAction(title: "Done", selector: #selector(UIView.layoutIfNeeded)), target: nil, spacing: 4
        )
        XCTAssertEqual(plain.frame.height, UIConstants.accessoryBarHeight)
        XCTAssertNil(plain.items)
    }

    func testStackHelpersApplyAxisMarginsAndSpacerConstraints() {
        let label = UILabel()
        let fixed = UIView.spacer(length: 12)
        let flexible = UIView.spacer(minLength: 4)
        let horizontal = UIView.hStack(alignment: .center, distribution: .fill, spacing: 2, margins: UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4), [
            label, fixed, flexible
        ])
        XCTAssertEqual(horizontal.axis, .horizontal)
        XCTAssertEqual(horizontal.alignment, .center)
        XCTAssertEqual(horizontal.spacing, 2)
        XCTAssertTrue(horizontal.isLayoutMarginsRelativeArrangement)
        XCTAssertEqual(horizontal.layoutMargins, UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
        let vertical = UIView.vStack(spacing: 5, [horizontal, UIView.spacer(length: 8)])
        XCTAssertEqual(vertical.axis, .vertical)
        XCTAssertFalse(vertical.isLayoutMarginsRelativeArrangement)

        let window = CovEHost.window(for: vertical, frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        defer { CovEHost.close(window) }
        vertical.updateConstraintsIfNeeded()
        XCTAssertTrue(fixed.constraints.contains { $0.firstAttribute == .width && $0.relation == .equal && $0.constant == 12 })
        XCTAssertTrue(flexible.constraints.contains { $0.firstAttribute == .width && $0.relation == .greaterThanOrEqual })
        horizontal.axis = .vertical
        horizontal.updateConstraintsIfNeeded()
        fixed.updateConstraintsIfNeeded()
        XCTAssertTrue(fixed.constraints.contains { $0.firstAttribute == .height && $0.constant == 12 }, "Spacers follow the stack's axis")
        fixed.removeFromSuperview()
        let loose = UIView()
        loose.addSubview(fixed)
        fixed.updateConstraintsIfNeeded()
        XCTAssertEqual(Set(fixed.constraints.map(\.firstAttribute)), [.width, .height], "Outside a stack both dimensions are held")
    }

    // The SwiftUI preview is compiled only in DEBUG builds.
    #if DEBUG
        func testStacksPreviewRendersTheExampleLayout() {
            let host = UIHostingController(rootView: ExampleView_Preview.previews)
            let window = CovEHost.window(for: host)
            defer { CovEHost.close(window) }
            CovEHost.spin(until: { CovEFind.label("Explore the render loop", in: host.view) != nil })
            XCTAssertNotNil(CovEFind.label("Explore the render loop", in: host.view))
            XCTAssertNotNil(CovEFind.label("20:21", in: host.view))
            XCTAssertFalse(CovEFind.all(UIStackView.self, in: host.view).isEmpty)
        }
    #endif
}

final class CovEAccessoryDelegate: AmountInputAccessoryViewDelegate {
    private(set) var percentages: [Float] = []
    private(set) var dones = 0

    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        percentages.append(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        dones += 1
    }
}
