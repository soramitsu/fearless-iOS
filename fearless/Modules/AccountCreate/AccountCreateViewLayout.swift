import UIKit
import SoraUI
import SoraFoundation
import SnapKit

final class AccountCreateViewLayout: UIView {
    private enum Constants {
        static let subviewToContainerOffset: CGFloat = 1
        static let strokeWidth: CGFloat = 1
        static let shadowOpacity: Float = 0
        static let dervationFieldToImageSpacing: CGFloat = 5
        static let derivationImageSize: Int = 24
        static let derivationPathLabelHeight: CGFloat = 15
        static let derivationPathViewToLabelSpacing: CGFloat = 12
        static let contentBottomOffset: CGFloat = 92
    }

    let flow: AccountCreateFlow
    let adaptiveCreate = FWAppearance.accountCreateRestyled
    private var advancedHeaderHeight: Constraint?
    let headingLabel = UILabel()
    private let substrateDerivationCaption = UILabel()
    private let ethereumDerivationCaption = UILabel()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
                applyTypography()
            }
        }
    }

    var mnemonicView: MnemonicDisplayView? {
        didSet { applyMnemonicTypography() }
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let nextButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let backupButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = R.color.colorBlack19()!
        button.triangularedView?.highlightedFillColor = R.color.colorBlack19()!
        button.triangularedView?.strokeColor = R.color.colorWhite50()!
        button.triangularedView?.highlightedStrokeColor = R.color.colorWhite50()!
        button.triangularedView?.strokeWidth = 1

        button.imageWithTitleView?.iconImage = R.image.googleBackup()
        button.imageWithTitleView?.titleColor = R.color.colorWhite()
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    let substrateDerivationPathImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    let ethereumDerivationPathImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    let substrateCryptoTypeView: BorderedSubtitleActionView = {
        let view = BorderedSubtitleActionView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorGray()!
        view.highlightedStrokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        view.shadowOpacity = Constants.shadowOpacity
        view.actionControl.contentView.titleLabel.textColor = R.color.colorLightGray()
        view.actionControl.layoutType = BaseActionControl.LayoutType.flexible
        view.actionControl.contentView.titleLabel.font = .p2Paragraph
        view.actionControl.contentView.subtitleLabelView.textColor = R.color.colorWhite()
        view.actionControl.contentView.subtitleLabelView.font = .p1Paragraph
        view.actionControl.imageIndicator.image = R.image.iconDropDown()
        return view
    }()

    let ethereumCryptoTypeView: BorderedSubtitleActionView = {
        let view = BorderedSubtitleActionView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorGray()!
        view.highlightedStrokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        view.shadowOpacity = Constants.shadowOpacity
        view.actionControl.contentView.titleLabel.textColor = R.color.colorLightGray()
        view.actionControl.layoutType = BaseActionControl.LayoutType.flexible
        view.actionControl.contentView.titleLabel.font = .p2Paragraph
        view.actionControl.contentView.subtitleLabelView.textColor = R.color.colorWhite()
        view.actionControl.contentView.subtitleLabelView.font = .p1Paragraph
        view.actionControl.imageIndicator.image = R.image.iconDropDown()
        view.disable()
        return view
    }()

    let substrateDerivationPathField: UITextField = {
        let view = UITextField()
        view.tintColor = R.color.colorWhite()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.clearButtonMode = .whileEditing
        view.returnKeyType = .done
        return view
    }()

    let ethereumDerivationPathField: UITextField = {
        let view = UITextField()
        view.tintColor = R.color.colorWhite()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.clearButtonMode = .whileEditing
        view.returnKeyType = .done
        return view
    }()

    let substrateDerivationPathLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .left
        return label
    }()

    let ethereumDerivationPathLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .left
        return label
    }()

    private let expandableControlContainerView: BorderedContainerView = {
        let view = UIFactory().createBorderedContainerView()
        view.backgroundColor = R.color.colorBlack19()
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorGray()!
        return view
    }()

    private let expandableControl: ExpandableActionControl = {
        let view = UIFactory().createExpandableActionControl()
        view.backgroundColor = R.color.colorBlack19()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let detailsLabelView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack19()!
        return view
    }()

    private let substrateDerivationContainerView: TriangularedView = {
        let view = TriangularedView()
        view.shadowOpacity = Constants.shadowOpacity
        view.fillColor = UIColor.clear
        view.highlightedFillColor = UIColor.clear
        view.strokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        return view
    }()

    private let ethereumDerivationContainerView: TriangularedView = {
        let view = TriangularedView()
        view.shadowOpacity = Constants.shadowOpacity
        view.fillColor = UIColor.clear
        view.highlightedFillColor = UIColor.clear
        view.strokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        return view
    }()

    private let advancedContainerView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = UIConstants.bigOffset
        return stackView
    }()

    private let advancedAppearanceAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromBottom,
        curve: .easeOut
    )

    private let advancedDismissalAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromTop,
        curve: .easeIn
    )

    let buttonVStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)

    var keyboardAdoptableConstraint: Constraint?

    init(flow: AccountCreateFlow) {
        self.flow = flow
        super.init(frame: .zero)
        setupLayout()
        configure()
        applyLocalization()
        applyTypography()

        backgroundColor = R.color.colorBlack19()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            applyTypography()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard adaptiveCreate else { return }
        let inset = expandableControl.plusIndicator.intrinsicContentSize.width + expandableControl.horizontalSpacing
        let width = max(1, contentView.bounds.width - inset)
        expandableControl.titleLabel.preferredMaxLayoutWidth = width
        advancedHeaderHeight?.update(offset: max(
            60,
            ceil(
                expandableControl.titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
                    .height
            ) + 32
        ))
        expandableControl.invalidateLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AccountCreateViewLayout {
    func set(chainType: AccountCreateChainType) {
        substrateDerivationContainerView.isHidden = !chainType.includeSubstrate
        substrateDerivationPathField.isHidden = !chainType.includeSubstrate
        substrateDerivationPathImage.isHidden = !chainType.includeSubstrate
        substrateDerivationPathLabel.isHidden = !chainType.includeSubstrate
        substrateCryptoTypeView.isHidden = !chainType.includeSubstrate

        ethereumDerivationContainerView.isHidden = !chainType.includeEthereum
        ethereumDerivationPathField.isHidden = !chainType.includeEthereum
        ethereumDerivationPathImage.isHidden = !chainType.includeEthereum
        ethereumDerivationPathLabel.isHidden = !chainType.includeEthereum
        ethereumCryptoTypeView.isHidden = !chainType.includeEthereum
    }

    func handleKeyboard(frame: CGRect) {
        if adaptiveCreate {
            keyboardAdoptableConstraint?.update(inset: frame.height)
            return
        }
        nextButton.snp.updateConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(frame.height + UIConstants.bigOffset)
        }
    }
}

private extension AccountCreateViewLayout {
    func applyMnemonicTypography() {
        guard adaptiveCreate, let mnemonicView else { return }
        mnemonicView.adaptsToAvailableWidth = true
        mnemonicView.indexFontInColumn = .fw(.monoS, locale: locale, compatibleWith: traitCollection)
        mnemonicView.wordFontInColumn = .fw(.phraseWord, locale: locale, compatibleWith: traitCollection)
        mnemonicView.verticalSpacingInColumn = 12
    }

    func applyTypography() {
        guard adaptiveCreate else { return }
        applyMnemonicTypography()
        headingLabel.font = .fw(.titleL, locale: locale, compatibleWith: traitCollection)
        detailsLabel.font = .fw(.bodyL, locale: locale, compatibleWith: traitCollection)
        [nextButton, backupButton]
            .forEach { $0.configureWrappingTitle(locale: locale, compatibleWith: traitCollection) }
        [substrateCryptoTypeView, ethereumCryptoTypeView]
            .forEach { $0.configureWrapping(locale: locale, compatibleWith: traitCollection) }
        [
            substrateDerivationCaption,
            ethereumDerivationCaption,
            substrateDerivationPathLabel,
            ethereumDerivationPathLabel
        ].forEach {
            $0.numberOfLines = 0
            $0.textColor = R.color.colorLightGray()
            $0.font = .fw(.bodyS, locale: locale, compatibleWith: traitCollection)
        }
        [substrateDerivationPathField, ethereumDerivationPathField].forEach {
            $0.font = .fw(.bodyL, locale: locale, compatibleWith: traitCollection)
            $0.invalidateIntrinsicContentSize()
        }
        expandableControl.titleLabel.numberOfLines = 0
        expandableControl.titleLabel.font = .fw(.labelL, locale: locale, compatibleWith: traitCollection)
        expandableControl.invalidateLayout()
        setNeedsLayout()
    }

    private func configure() {
        contentView.stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack19() }
        advancedContainerView.isHidden = !expandableControl.isActivated
        expandableControl.addTarget(self, action: #selector(actionExpand), for: .touchUpInside)
        setupEthereumDerivationPathTextField()
    }

    private func setupEthereumDerivationPathTextField() {
        let bar = UIToolbar()
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let close = UIBarButtonItem(
            title: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            style: .done, target: self, action: #selector(close)
        )
        bar.items = [flexibleSpace, close]
        bar.sizeToFit()
        ethereumDerivationPathField.inputAccessoryView = bar
    }

    @objc private func close() {
        ethereumDerivationPathField.resignFirstResponder()
    }

    @objc
    private func actionExpand() {
        contentView.stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !expandableControl.isActivated

        if expandableControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            substrateDerivationPathField.resignFirstResponder()
            ethereumDerivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            if adaptiveCreate {
                keyboardAdoptableConstraint = make.bottom.equalToSuperview().constraint
            } else {
                make.bottom.equalToSuperview().inset(Constants.contentBottomOffset)
            }
        }

        if adaptiveCreate {
            headingLabel.numberOfLines = 0
            headingLabel.textColor = R.color.colorWhite()
            headingLabel.accessibilityTraits = .header
            contentView.stackView.addArrangedSubview(headingLabel)
            contentView.stackView.spacing = 16
            contentView.stackView.layoutMargins.bottom = 24
        }
        detailsLabelView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }
        contentView.stackView.addArrangedSubview(detailsLabelView)

        setupAdvancedLayout()
        setupActionLayout()
    }

    private func setupAdvancedLayout() {
        expandableControlContainerView.snp.makeConstraints { make in
            if adaptiveCreate {
                advancedHeaderHeight = make.height.equalTo(60).constraint
            } else {
                make.height.equalTo(UIConstants.expandableViewHeight)
            }
        }
        expandableControlContainerView.addSubview(expandableControl)
        expandableControl.snp.makeConstraints { make in
            make.edges.equalTo(expandableControlContainerView)
        }

        contentView.stackView.addArrangedSubview(expandableControlContainerView)

        advancedContainerView.addArrangedSubview(substrateCryptoTypeView)
        if !adaptiveCreate {
            substrateCryptoTypeView.snp.makeConstraints { $0.height.equalTo(UIConstants.actionHeight) }
        }

        setupDerivationField(
            field: substrateDerivationPathField, caption: substrateDerivationCaption,
            image: substrateDerivationPathImage, container: substrateDerivationContainerView,
            example: substrateDerivationPathLabel
        )

        advancedContainerView.addArrangedSubview(ethereumCryptoTypeView)
        if !adaptiveCreate {
            ethereumCryptoTypeView.snp.makeConstraints { $0.height.equalTo(UIConstants.actionHeight) }
        }

        setupDerivationField(
            field: ethereumDerivationPathField, caption: ethereumDerivationCaption,
            image: ethereumDerivationPathImage, container: ethereumDerivationContainerView,
            example: ethereumDerivationPathLabel
        )

        contentView.stackView.addArrangedSubview(advancedContainerView)
    }

    private func setupActionLayout() {
        if adaptiveCreate {
            contentView.stackView.addArrangedSubview(buttonVStackView)
        } else {
            addSubview(buttonVStackView)
            buttonVStackView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(UIConstants.bigOffset)
                make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
                keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
                    .constraint
            }
        }

        buttonVStackView.addArrangedSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            if adaptiveCreate {
                make.height.greaterThanOrEqualTo(56)
            } else {
                make.height.equalTo(UIConstants.actionHeight)
            }
            make.leading.trailing.equalToSuperview()
        }

        switch flow {
        case .wallet:
            buttonVStackView.addArrangedSubview(backupButton)
            backupButton.snp.makeConstraints { make in
                if adaptiveCreate {
                    make.height.greaterThanOrEqualTo(56)
                } else {
                    make.height.equalTo(UIConstants.actionHeight)
                }
            }
        case .chain:
            backupButton.isHidden = true
        case .backup:
            expandableControl.isHidden = true
            if adaptiveCreate { expandableControlContainerView.isHidden = true }
        }
    }

    private func setupDerivationField(
        field: UITextField, caption: UILabel, image: UIImageView,
        container: TriangularedView, example: UILabel
    ) {
        if adaptiveCreate {
            container.addSubview(caption)
            caption.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
                $0.top.equalToSuperview().offset(12)
            }
        }
        container.addSubview(field)
        field.snp.makeConstraints { make in
            if adaptiveCreate {
                make.top.equalTo(caption.snp.bottom).offset(8)
                make.bottom.equalToSuperview().inset(12)
                make.height.greaterThanOrEqualTo(32)
            } else {
                make.top.bottom.equalToSuperview().offset(UIConstants.defaultOffset)
            }
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
        container.addSubview(image)
        image.snp.makeConstraints { make in
            make.size.equalTo(Constants.derivationImageSize)
            make.leading.equalTo(field.snp.trailing).offset(Constants.dervationFieldToImageSpacing)
            if adaptiveCreate { make.centerY.equalTo(field) } else { make.centerY.equalToSuperview() }
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
        advancedContainerView.addArrangedSubview(container)
        advancedContainerView.addArrangedSubview(example)
        if !adaptiveCreate {
            container.snp.makeConstraints { $0.height.equalTo(UIConstants.actionHeight) }
            example.snp.makeConstraints { $0.height.equalTo(Constants.derivationPathLabelHeight) }
        }
    }

    private func applyLocalization() {
        expandableControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)

        switch flow {
        case .wallet, .chain:
            headingLabel.text = R.string.localizable.accountCreateTitle(preferredLanguages: locale.rLanguages)
            detailsLabel.text = R.string.localizable.accountCreateDetails(preferredLanguages: locale.rLanguages)
            nextButton.imageWithTitleView?.title = R.string.localizable
                .accountConfirmationTitle(preferredLanguages: locale.rLanguages)
        case .backup:
            headingLabel.text = R.string.localizable.backupMnemonicTitle(preferredLanguages: locale.rLanguages)
            detailsLabel.text = R.string.localizable.backupMnemonicDescription(preferredLanguages: locale.rLanguages)
            nextButton.imageWithTitleView?.title = R.string.localizable
                .commonContinue(preferredLanguages: locale.rLanguages)
        }
        backupButton.imageWithTitleView?.title = R.string.localizable
            .btnBackupWithGoogle(preferredLanguages: locale.rLanguages)
        substrateDerivationCaption.text = R.string.localizable
            .substrateSecretDerivationPath(preferredLanguages: locale.rLanguages)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        ethereumDerivationCaption.text = R.string.localizable
            .ethereumSecretDerivationPath(preferredLanguages: locale.rLanguages)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        (ethereumDerivationPathField.inputAccessoryView as? UIToolbar)?.items?.last?.title = R.string.localizable
            .commonClose(preferredLanguages: locale.rLanguages)
        if adaptiveCreate {
            [nextButton, backupButton]
                .forEach { $0.configureWrappingTitle(locale: locale, compatibleWith: traitCollection) }
        }
    }
}
