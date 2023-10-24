import UIKit
import SoraUI

// swiftlint:disable file_length type_body_length function_body_length
struct UIConstants {
    static let minimalOffset: CGFloat = 4.0
    static let defaultOffset: CGFloat = 8.0
    static let bigOffset: CGFloat = 16.0
    static let hugeOffset: CGFloat = 24.0
    static let actionBottomInset: CGFloat = 16.0
    static let actionHeight: CGFloat = 48.0
    static let mainAccessoryActionsSpacing: CGFloat = 16.0
    static let horizontalInset: CGFloat = 16.0
    static let verticalInset: CGFloat = 16.0
    static let triangularedViewHeight: CGFloat = 52.0
    static let expandableViewHeight: CGFloat = 50.0
    static let formSeparatorWidth: CGFloat = 0.5
    static let triangularedIconLargeRadius: CGFloat = 12.0
    static let triangularedIconSmallRadius: CGFloat = 9.0
    static let smallAddressIconSize = CGSize(width: 18.0, height: 18.0)
    static let normalAddressIconSize = CGSize(width: 32.0, height: 32.0)
    static let accessoryBarHeight: CGFloat = 44.0
    static let accessoryItemsSpacing: CGFloat = 12.0
    static let cellHeight: CGFloat = 48.0
    static let cellHeight54: CGFloat = 54.0
    static let cellHeight64: CGFloat = 64.0
    static let cellHeight40: CGFloat = 40.0
    static let tableHeaderHeight: CGFloat = 40.0
    static let separatorHeight: CGFloat = 1.0 / UIScreen.main.scale
    static let skeletonBigRowSize = CGSize(width: 72.0, height: 12.0)
    static let skeletonSmallRowSize = CGSize(width: 57.0, height: 6.0)
    static let amountInputIconSize = CGSize(width: 24.0, height: 24.0)
    static let networkFeeViewDefaultHeight: CGFloat = 132.0
    static let referralBonusButtonHeight: CGFloat = 30.0
    static let amountViewHeight: CGFloat = 72.0
    static let swipeTableActionButtonWidth: CGFloat = 88.0
    static let iconSize: CGFloat = 24.0
    static let standardButtonSize = CGSize(width: 36.0, height: 36.0)
    static let indicatorSize = CGSize(width: 35.0, height: 2.0)
    static let amountViewV2Height: CGFloat = 92.0
    static let offset12: CGFloat = 12.0
    static let statusViewHeight: CGFloat = 51.0
    static let validatorCellHeight: CGFloat = 77.0
    static let infoButtonSize: CGFloat = 14.0
    static let minButtonSize = CGSize(width: 44, height: 44)
    static let roundedButtonHeight: CGFloat = 56.0
    static let roundedCloseButtonSize: CGFloat = 32.0
}

enum AccountViewMode {
    case options
    case selection
    case none
}

protocol UIFactoryProtocol {
    func createVerticalStackView(spacing: CGFloat) -> UIStackView
    func createHorizontalStackView(spacing: CGFloat) -> UIStackView
    func createMainActionButton() -> TriangularedButton
    func createAccessoryButton() -> TriangularedButton
    func createDestructiveButton() -> TriangularedButton
    func createDetailsView(
        with layout: DetailsTriangularedView.Layout,
        filled: Bool
    ) -> DetailsTriangularedView
    func createExpandableActionControl() -> ExpandableActionControl
    func createTitledMnemonicView(_ title: String?, icon: UIImage?) -> TitledMnemonicView
    func createMultilinedTriangularedView() -> MultilineTriangularedView
    func createSeparatorView() -> UIView
    func createBorderedContainerView() -> BorderedContainerView
    func createActionsAccessoryView(
        for actions: [ViewSelectorAction],
        doneAction: ViewSelectorAction,
        target: Any?,
        spacing: CGFloat
    ) -> UIToolbar
    func createCommonInputView() -> CommonInputView
    func createAmountInputView(filled: Bool) -> AmountInputView
    func createAmountAccessoryView(
        for delegate: AmountInputAccessoryViewDelegate?,
        locale: Locale
    ) -> UIToolbar
    func createAccountView(for mode: AccountViewMode, filled: Bool) -> DetailsTriangularedView
    func createIdentityView(isSingleTitle: Bool) -> DetailsTriangularedView
    func createNetworkFeeView() -> NetworkFeeView
    func createNetworkFeeFooterView() -> NetworkFeeFooterView
    func createTitleValueView() -> TitleValueView
    func createIconTitleValueView(iconPosition: IconTitleValueView.IconPosition) -> IconTitleValueView
    func createTitleValueSelectionView() -> TitleValueSelectionView
    func createHintView() -> HintView
    func createLearnMoreView() -> LearnMoreView
    func createRewardSelectionView() -> RewardSelectionView
    func createInfoIndicatingView() -> ImageWithTitleView
    func createChainAssetSelectionView(layout: DetailsTriangularedView.Layout) -> DetailsTriangularedView
    func createWalletReferralBonusButton() -> GradientButton
    func createIndicatorView() -> RoundedView
    func createSearchTextField() -> SearchTextField
    func createInfoBackground() -> TriangularedView
    func createMultiView() -> TitleMultiValueView
    func createConfirmationMultiView() -> TitleMultiValueView
    func createSliderAccessoryView(
        for delegate: AmountInputAccessoryViewDelegate?,
        locale: Locale
    ) -> UIToolbar
    func createDisabledButton() -> TriangularedButton
    func createRoundedButton() -> UIButton
}

extension UIFactoryProtocol {
    func createAccountView() -> DetailsTriangularedView {
        createAccountView(for: .options, filled: false)
    }

    func createFearlessLearnMoreView() -> LearnMoreView {
        let view = createLearnMoreView()
        view.iconView.image = R.image.iconFearlessSmall()
        return view
    }
}

final class UIFactory: UIFactoryProtocol {
    static let `default` = UIFactory()

    func createVerticalStackView(spacing: CGFloat = 0) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = spacing
        return stackView
    }

    func createHorizontalStackView(spacing: CGFloat = 0) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = spacing
        return stackView
    }

    func createMainActionButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }
        button.applyEnabledStyle()
        return button
    }

    func createAccessoryButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applyAccessoryStyle()
        return button
    }

    func createDestructiveButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applyDestructiveStyle()
        return button
    }

    func createDisabledButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }

    func createDetailsView(
        with layout: DetailsTriangularedView.Layout,
        filled: Bool
    ) -> DetailsTriangularedView {
        let view = DetailsTriangularedView()
        view.layout = layout

        if filled {
            view.fillColor = R.color.colorSemiBlack()!
            view.highlightedFillColor = R.color.colorSemiBlack()!
            view.strokeColor = R.color.colorWhite8()!
            view.highlightedStrokeColor = R.color.colorWhite8()!
            view.borderWidth = 1
        } else {
            view.fillColor = .clear
            view.highlightedFillColor = .clear
            view.strokeColor = R.color.colorWhite8()!
            view.highlightedStrokeColor = R.color.colorWhite8()!
            view.borderWidth = 1
        }

        switch layout {
        case .largeIconTitleSubtitle, .singleTitle, .largeIconTitleInfoSubtitle:
            view.iconRadius = UIConstants.triangularedIconLargeRadius
        case .smallIconTitleSubtitle, .smallIconTitleButton, .smallIconTitleSubtitleButton:
            view.iconRadius = UIConstants.triangularedIconSmallRadius
        case .withoutIcon:
            view.iconView.removeFromSuperview()
        }

        view.titleLabel.textColor = R.color.colorLightGray()!
        view.titleLabel.font = UIFont.p2Paragraph
        view.subtitleLabel?.textColor = R.color.colorWhite()!
        view.subtitleLabel?.font = UIFont.p1Paragraph
        view.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)

        return view
    }

    func createExpandableActionControl() -> ExpandableActionControl {
        let view = ExpandableActionControl()
        view.layoutType = .flexible
        view.titleLabel.textColor = R.color.colorWhite()
        view.titleLabel.font = UIFont.p1Paragraph
        view.plusIndicator.strokeColor = R.color.colorWhite()!

        return view
    }

    func createTitledMnemonicView(_ title: String?, icon: UIImage?) -> TitledMnemonicView {
        let view = TitledMnemonicView()

        if let icon = icon {
            view.iconView.image = icon
        }

        if let title = title {
            view.titleLabel.textColor = R.color.colorLightGray()!
            view.titleLabel.font = UIFont.p1Paragraph
            view.titleLabel.text = title
        }

        view.contentView.indexTitleColorInColumn = R.color.colorGray()!
        view.contentView.wordTitleColorInColumn = R.color.colorWhite()!

        view.contentView.indexFontInColumn = .p0Digits
        view.contentView.wordFontInColumn = .p0Paragraph

        return view
    }

    func createMultilinedTriangularedView() -> MultilineTriangularedView {
        let view = MultilineTriangularedView()
        view.backgroundView.fillColor = R.color.colorDarkGray()!
        view.backgroundView.highlightedFillColor = R.color.colorDarkGray()!
        view.backgroundView.strokeColor = .clear
        view.backgroundView.highlightedStrokeColor = .clear
        view.backgroundView.strokeWidth = 0.0
        view.backgroundView.shadowOpacity = 0

        view.titleLabel.textColor = R.color.colorLightGray()!
        view.titleLabel.font = UIFont.p2Paragraph
        view.subtitleLabel?.textColor = R.color.colorWhite()!
        view.subtitleLabel?.font = UIFont.p1Paragraph

        return view
    }

    func createSeparatorView() -> UIView {
        let view = UIView()
        view.backgroundColor = R.color.colorDarkGray()!
        return view
    }

    func createBorderedContainerView() -> BorderedContainerView {
        let view = BorderedContainerView()
        view.borderType = .bottom
        view.strokeWidth = UIConstants.separatorHeight
        view.strokeColor = R.color.colorDarkGray()!
        return view
    }

    func createActionsAccessoryView(
        for _: [ViewSelectorAction],
        doneAction _: ViewSelectorAction,
        target _: Any?,
        spacing _: CGFloat
    ) -> UIToolbar {
        let frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: UIScreen.main.bounds.width,
            height: UIConstants.accessoryBarHeight
        )

        let toolBar = UIToolbar(frame: frame)

        return toolBar
    }

    func createAmountAccessoryView(
        for delegate: AmountInputAccessoryViewDelegate?,
        locale: Locale
    ) -> UIToolbar {
        let frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: UIScreen.main.bounds.width,
            height: UIConstants.accessoryBarHeight
        )

        let toolBar = AmountInputAccessoryView(frame: frame)
        toolBar.actionDelegate = delegate

        let maxTitle = R.string.localizable.commonMax(preferredLanguages: locale.rLanguages)
        let actions: [ViewSelectorAction] = [
            ViewSelectorAction(title: maxTitle.uppercased(), selector: #selector(toolBar.actionSelect100)),
            ViewSelectorAction(title: "75%", selector: #selector(toolBar.actionSelect75)),
            ViewSelectorAction(title: "50%", selector: #selector(toolBar.actionSelect50)),
            ViewSelectorAction(title: "25%", selector: #selector(toolBar.actionSelect25))
        ]

        let doneTitle = R.string.localizable.commonDone(preferredLanguages: locale.rLanguages)
        let doneAction = ViewSelectorAction(
            title: doneTitle,
            selector: #selector(toolBar.actionSelectDone)
        )

        let spacing: CGFloat

        if toolBar.isAdaptiveWidthDecreased {
            spacing = UIConstants.accessoryItemsSpacing * toolBar.designScaleRatio.width
        } else {
            spacing = UIConstants.accessoryItemsSpacing
        }

        return createActionsAccessoryView(
            for: toolBar,
            actions: actions,
            doneAction: doneAction,
            target: toolBar,
            spacing: spacing
        )
    }

    func createSliderAccessoryView(
        for delegate: AmountInputAccessoryViewDelegate?,
        locale: Locale
    ) -> UIToolbar {
        let frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: UIScreen.main.bounds.width,
            height: UIConstants.accessoryBarHeight
        )

        let toolBar = AmountInputAccessoryView(frame: frame)
        toolBar.actionDelegate = delegate

        let actions: [ViewSelectorAction] = [
            ViewSelectorAction(title: "0.1%", selector: #selector(toolBar.actionSelect01)),
            ViewSelectorAction(title: "0.5%", selector: #selector(toolBar.actionSelect05)),
            ViewSelectorAction(title: "1%", selector: #selector(toolBar.actionSelect100))
        ]

        let doneTitle = R.string.localizable.commonDone(preferredLanguages: locale.rLanguages)
        let doneAction = ViewSelectorAction(
            title: doneTitle,
            selector: #selector(toolBar.actionSelectDone)
        )

        let spacing: CGFloat

        if toolBar.isAdaptiveWidthDecreased {
            spacing = UIConstants.accessoryItemsSpacing * toolBar.designScaleRatio.width
        } else {
            spacing = UIConstants.accessoryItemsSpacing
        }

        return createActionsAccessoryView(
            for: toolBar,
            actions: actions,
            doneAction: doneAction,
            target: toolBar,
            spacing: spacing
        )
    }

    func createCommonInputView() -> CommonInputView {
        CommonInputView()
    }

    func createAmountInputView(filled: Bool) -> AmountInputView {
        let amountInputView = AmountInputView()

        if !filled {
            amountInputView.triangularedBackgroundView?.strokeColor = R.color.colorPink()!
            amountInputView.triangularedBackgroundView?.highlightedStrokeColor = R.color.colorPink()!
            amountInputView.triangularedBackgroundView?.strokeWidth = 1.0
            amountInputView.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
            amountInputView.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        } else {
            amountInputView.triangularedBackgroundView?.strokeWidth = 0.0
            amountInputView.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
            amountInputView.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
            amountInputView.triangularedBackgroundView?.strokeColor = R.color.colorWhite8()!
        }

        amountInputView.titleLabel.textColor = R.color.colorWhite()
        amountInputView.titleLabel.font = .h5Title
        amountInputView.priceLabel.textColor = R.color.colorGray()
        amountInputView.priceLabel.font = .p1Paragraph
        amountInputView.symbolLabel.textColor = R.color.colorWhite()
        amountInputView.symbolLabel.font = .h3Title
        amountInputView.balanceLabel.textColor = R.color.colorGray()
        amountInputView.balanceLabel.font = .p1Paragraph
        amountInputView.textField.font = .h2Title
        amountInputView.textField.textColor = R.color.colorWhite()
        amountInputView.textField.tintColor = R.color.colorPink()
        amountInputView.verticalSpacing = 2.0
        amountInputView.iconRadius = 12.0
        amountInputView.contentInsets = UIEdgeInsets(
            top: 8.0,
            left: UIConstants.horizontalInset,
            bottom: 8.0,
            right: UIConstants.horizontalInset
        )

        amountInputView.textField.attributedPlaceholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: R.color.colorWhite()!.withAlphaComponent(0.5),
                .font: UIFont.h2Title
            ]
        )

        amountInputView.textField.keyboardType = .decimalPad

        return amountInputView
    }

    private func createActionsAccessoryView(
        for toolBar: UIToolbar,
        actions: [ViewSelectorAction],
        doneAction: ViewSelectorAction,
        target: Any?,
        spacing: CGFloat
    ) -> UIToolbar {
        toolBar.isTranslucent = false

        let background = UIImage.background(from: R.color.colorAlmostBlack()!)
        toolBar.setBackgroundImage(
            background,
            forToolbarPosition: .any,
            barMetrics: .default
        )

        let actionAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.p1Paragraph
        ]

        let barItems = actions.reduce([UIBarButtonItem]()) { result, action in
            let barItem = UIBarButtonItem(
                title: action.title,
                style: .plain,
                target: target,
                action: action.selector
            )
            barItem.setTitleTextAttributes(actionAttributes, for: .normal)
            barItem.setTitleTextAttributes(actionAttributes, for: .highlighted)

            if result.isEmpty {
                return [barItem]
            } else {
                let fixedSpacing = UIBarButtonItem(
                    barButtonSystemItem: .fixedSpace,
                    target: nil,
                    action: nil
                )
                fixedSpacing.width = spacing

                return result + [fixedSpacing, barItem]
            }
        }

        let flexibleSpacing = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        let doneItem = UIBarButtonItem(
            title: doneAction.title,
            style: .done,
            target: target,
            action: doneAction.selector
        )

        let doneAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.h5Title
        ]

        doneItem.setTitleTextAttributes(doneAttributes, for: .normal)
        doneItem.setTitleTextAttributes(doneAttributes, for: .highlighted)

        toolBar.setItems(barItems + [flexibleSpacing, doneItem], animated: true)

        return toolBar
    }

    func createAccountView(for mode: AccountViewMode, filled: Bool) -> DetailsTriangularedView {
        let view = createDetailsView(with: .largeIconTitleSubtitle, filled: filled)
        view.subtitleLabel?.lineBreakMode = .byTruncatingMiddle

        switch mode {
        case .options:
            view.actionImage = R.image.iconMore()
        case .selection:
            view.actionImage = R.image.iconExpandable()
        case .none:
            view.actionView.image = nil
        }

        view.highlightedFillColor = R.color.colorHighlightedPink()!
        view.borderWidth = 1
        return view
    }

    func createIdentityView(isSingleTitle: Bool) -> DetailsTriangularedView {
        let view = DetailsTriangularedView()

        view.titleLabel.textColor = R.color.colorWhite()!
        view.titleLabel.font = UIFont.p1Paragraph

        if isSingleTitle {
            view.layout = .singleTitle
            view.titleLabel.lineBreakMode = .byTruncatingMiddle
        } else {
            view.layout = .largeIconTitleSubtitle

            view.subtitleLabel?.textColor = R.color.colorLightGray()!
            view.subtitleLabel?.font = UIFont.p2Paragraph

            view.titleLabel.lineBreakMode = .byTruncatingTail
            view.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        }

        view.actionImage = R.image.iconMore()

        view.iconRadius = 16.0

        view.fillColor = .clear
        view.highlightedFillColor = R.color.colorHighlightedPink()!
        view.strokeColor = R.color.colorStrokeGray()!
        view.highlightedStrokeColor = R.color.colorStrokeGray()!
        view.borderWidth = 1.0

        view.contentInsets = UIEdgeInsets(top: 8.0, left: 11.0, bottom: 8.0, right: 16.0)

        return view
    }

    func createNetworkFeeView() -> NetworkFeeView {
        NetworkFeeView()
    }

    func createNetworkFeeFooterView() -> NetworkFeeFooterView {
        NetworkFeeFooterView()
    }

    func createCleanNetworkFeeFooterView() -> NetworkFeeFooterView {
        let view = NetworkFeeFooterView()
        view.networkFeeView?.titleLabel.font = .p2Paragraph
        view.networkFeeView?.titleLabel.textColor = R.color.colorStrokeGray()
        view.networkFeeView?.borderType = .none
        view.durationView?.borderView.isHidden = true
        return view
    }

    func createTitleValueView() -> TitleValueView {
        TitleValueView()
    }

    func createIconTitleValueView(iconPosition: IconTitleValueView.IconPosition = .left) -> IconTitleValueView {
        IconTitleValueView(iconPosition: iconPosition)
    }

    func createHintView() -> HintView {
        HintView()
    }

    func createLearnMoreView() -> LearnMoreView {
        let view = LearnMoreView()
        view.contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
        return view
    }

    func createTitleValueSelectionView() -> TitleValueSelectionView {
        TitleValueSelectionView()
    }

    func createRewardSelectionView() -> RewardSelectionView {
        let view = RewardSelectionView()

        view.borderWidth = 1.0
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorGray()!
        view.highlightedStrokeColor = R.color.colorPink()!
        view.titleColor = R.color.colorWhite()!
        view.amountTitleColor = R.color.colorWhite()!
        view.priceColor = R.color.colorLightGray()!
        view.incomeColor = R.color.colorGreen()!

        view.titleLabel.font = .h5Title
        view.amountLabel.font = .h6Title
        view.priceLabel.font = .p2Paragraph
        view.incomeLabel.font = .p2Paragraph

        view.iconView.image = R.image.listCheckmarkIcon()!
        view.isSelected = false

        return view
    }

    func createInfoIndicatingView() -> ImageWithTitleView {
        let view = ImageWithTitleView()
        view.titleColor = R.color.colorLightGray()
        view.titleFont = .p1Paragraph
        view.layoutType = .horizontalLabelFirst
        view.spacingBetweenLabelAndIcon = 5.0
        view.iconImage = R.image.iconInfoFilled()
        return view
    }

    func createChainAssetSelectionView(layout: DetailsTriangularedView.Layout = .largeIconTitleSubtitle) -> DetailsTriangularedView {
        let view = DetailsTriangularedView()
        view.layout = layout
        view.fillColor = .clear
        view.highlightedFillColor = R.color.colorCellSelection()!
        view.titleLabel.textColor = R.color.colorWhite()
        view.titleLabel.font = .p1Paragraph
        view.subtitleLabel?.textColor = R.color.colorLightGray()
        view.subtitleLabel?.font = .p2Paragraph
        view.actionImage = R.image.iconHorMore()
        view.contentInsets = UIEdgeInsets(top: 7.0, left: 16.0, bottom: 8.0, right: 16.0)
        view.iconRadius = 16.0
        return view
    }

    func createWalletReferralBonusButton() -> GradientButton {
        let button = GradientButton()
        button.applyEnabledStyle()
        button.applyDisabledStyle()
        button.gradientBackgroundView?.cornerRadius = UIConstants.referralBonusButtonHeight / 2

        return button
    }

    func createChainOptionsView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.alignment = .fill
        stackView.spacing = UIConstants.defaultOffset
        return stackView
    }

    func createIndicatorView() -> RoundedView {
        let indicator = RoundedView()
        indicator.roundingCorners = .allCorners
        indicator.cornerRadius = UIConstants.indicatorSize.height / 2.0
        indicator.fillColor = R.color.colorLightGray()!
        indicator.highlightedFillColor = R.color.colorLightGray()!
        indicator.shadowOpacity = 0.0
        return indicator
    }

    func createNetworkView(selectable: Bool) -> DetailsTriangularedView {
        let view = createDetailsView(with: .largeIconTitleSubtitle, filled: true)
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.titleLabel.font = UIFont.h5Title
        if selectable {
            view.actionImage = R.image.iconExpandable()
        }
        return view
    }

    func createSearchTextField() -> SearchTextField {
        let searchTextField = SearchTextField()
        searchTextField.triangularedView?.cornerCut = [.bottomRight, .topLeft]
        searchTextField.triangularedView?.strokeWidth = UIConstants.separatorHeight
        searchTextField.triangularedView?.strokeColor = R.color.colorStrokeGray() ?? .lightGray
        searchTextField.triangularedView?.fillColor = R.color.colorWhite8()!
        searchTextField.triangularedView?.highlightedFillColor = R.color.colorWhite8()!
        searchTextField.triangularedView?.shadowOpacity = 0
        return searchTextField
    }

    func createInfoBackground() -> TriangularedView {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }

    func createMultiView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.borderView.borderType = .none
        view.titleLabel.font = .p2Paragraph
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h6Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p2Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }

    func createConfirmationMultiView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.borderView.borderType = .none
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }

    func createRoundedButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .h6Title
        button.layer.cornerRadius = 12
        return button
    }
}
