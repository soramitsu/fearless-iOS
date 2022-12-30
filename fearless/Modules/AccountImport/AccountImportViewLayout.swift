import UIKit
import SoraUI
import SnapKit

final class AccountImportViewLayout: UIView {
    private enum Constants {
        static let strokeWidth: CGFloat = 1
        static let shadowOpacity: Float = 0
        static let textViewHeight: CGFloat = 102
        static let dervationFieldToImageSpacing: CGFloat = 5
        static let derivationImageSize: Int = 24
        static let derivationPathLabelHeight: CGFloat = 15
        static let derivationPathViewToLabelSpacing: CGFloat = 12
        static let contentBottomOffset: CGFloat = 92
        static let usernameTextFieldContentInsets = UIEdgeInsets(
            top: 4.0,
            left: 0.0,
            bottom: 4.0,
            right: 0.0
        )
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                setupLocalization()
            }
        }
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.alignment = .fill
        return view
    }()

    let sourceTypeView: BorderedSubtitleActionView = {
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
        view.actionControl.contentView.subtitleLabelView.numberOfLines = 1
        view.actionControl.contentView.subtitleImageView.isHidden = true
        view.actionControl.imageIndicator.image = R.image.iconDropDown()
        return view
    }()

    let sourceTypeViewContainer = UIView()

    let chainView: BorderedSubtitleActionView = {
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
        view.actionControl.contentView.subtitleLabelView.numberOfLines = 1
        view.actionControl.imageIndicator.image = R.image.iconDropDown()
        view.disable()
        return view
    }()

    let chainViewContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    let usernameTextField: CommonInputView = {
        let inputView = CommonInputView()
        inputView.backgroundView.strokeColor = R.color.colorGray()!
        inputView.backgroundView.highlightedStrokeColor = R.color.colorGray()!
        inputView.animatedInputField.placeholderColor = R.color.colorLightGray()!
        inputView.animatedInputField.contentInsets = Constants.usernameTextFieldContentInsets
        inputView.defaultSetup()
        return inputView
    }()

    let usernameTextFieldContainer = UIView()

    let usernameFooterLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let usernameLabelContainer = UIView()

    let passwordTextField: CommonInputView = {
        let inputView = CommonInputView()
        inputView.backgroundView.strokeColor = R.color.colorGray()!
        inputView.backgroundView.highlightedStrokeColor = R.color.colorGray()!
        inputView.animatedInputField.placeholderColor = R.color.colorLightGray()!
        inputView.defaultSetup()
        inputView.animatedInputField.textField.isSecureTextEntry = true
        return inputView
    }()

    let passwordContainerView = UIView()

    let textPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let textView: UITextView = {
        let view = UITextView()
        view.textColor = R.color.colorWhite()
        view.font = .p1Paragraph
        view.tintColor = R.color.colorWhite()
        view.keyboardType = .default
        view.autocapitalizationType = .none
        return view
    }()

    let textTriangularedView: TriangularedView = {
        let view = TriangularedView()
        view.shadowOpacity = Constants.shadowOpacity
        view.fillColor = R.color.colorBlack()!
        view.highlightedFillColor = R.color.colorBlack()!
        view.strokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        return view
    }()

    let textViewContainer = UIView()

    let uploadView: DetailsTriangularedView = {
        let detailsView = UIFactory().createDetailsView(with: .largeIconTitleSubtitle, filled: false)
        detailsView.fillColor = UIColor.clear
        detailsView.highlightedFillColor = R.color.colorHighlightedAccent()!
        detailsView.highlightedFillColor = R.color.colorHighlightedPink()!
        detailsView.strokeColor = R.color.colorStrokeGray()!
        detailsView.highlightedStrokeColor = R.color.colorStrokeGray()!
        detailsView.borderWidth = 1
        detailsView.titleColor = R.color.colorLightGray()
        detailsView.subtitleColor = R.color.colorWhite()
        detailsView.titleLabel.font = .p2Paragraph
        detailsView.contentInsets = UIEdgeInsets(
            top: UIConstants.defaultOffset,
            left: UIConstants.bigOffset,
            bottom: UIConstants.defaultOffset,
            right: UIConstants.bigOffset
        )
        detailsView.subtitleLabel?.font = .p1Paragraph
        detailsView.iconImage = R.image.iconUpload()
        return detailsView
    }()

    let uploadViewContainer = UIView()

    let nextButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let warningContainerView = UIView()

    let warningLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let warningImage: UIImageView = {
        let imageView = UIImageView(image: R.image.iconAlert())
        imageView.tintColor = R.color.colorWhite()
        imageView.contentMode = .scaleAspectFit
        return imageView
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
        view.clearButtonMode = .never
        view.returnKeyType = .done
        return view
    }()

    let ethereumDerivationPathField: UITextField = {
        let view = UITextField()
        view.tintColor = R.color.colorWhite()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.clearButtonMode = .never
        view.keyboardType = .decimalPad
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

    let advancedStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = UIConstants.bigOffset
        return stackView
    }()

    let advancedContainerView = UIView()

    let expandableControl: ExpandableActionControl = {
        let view = UIFactory().createExpandableActionControl()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
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

    private let expandableControlBorderedView: BorderedContainerView = {
        let view = UIFactory().createBorderedContainerView()
        view.backgroundColor = R.color.colorBlack()
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorGray()!
        return view
    }()

    let expandableControlContainerView = UIView()

    var advancedAppearanceAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromBottom,
        curve: .easeOut
    )

    var advancedDismissalAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromTop,
        curve: .easeIn
    )

    var keyboardAdoptableConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configure()
        backgroundColor = R.color.colorBlack()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AccountImportViewLayout {
    func updateTextViewPlaceholder() {
        textPlaceholderLabel.isHidden = !textView.text.isEmpty
    }

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

    func setAdvancedVisibility(_ visible: Bool) {
        expandableControlContainerView.isHidden = !visible
        expandableControl.isHidden = !visible
        advancedContainerView.isHidden = !visible
    }

    func setUsernameVisibility(_ visible: Bool) {
        usernameTextFieldContainer.isHidden = !visible
        usernameLabelContainer.isHidden = !visible
    }
}

private extension AccountImportViewLayout {
    func configure() {
        contentView.stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }

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

    func setupLocalization() {
        sourceTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale.rLanguages)

        chainView.actionControl.contentView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)

        usernameTextField.title = R.string.localizable
            .usernameSetupChooseTitle(preferredLanguages: locale.rLanguages)

        usernameFooterLabel.text = R.string.localizable
            .usernameSetupHint20(preferredLanguages: locale.rLanguages)

        passwordTextField.title = R.string.localizable
            .accountImportPasswordPlaceholder(preferredLanguages: locale.rLanguages)

        expandableControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)
        expandableControl.invalidateLayout()

        substrateCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .substrateCryptoType(preferredLanguages: locale.rLanguages)
        substrateCryptoTypeView.actionControl.invalidateLayout()
        ethereumCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .ethereumCryptoType(preferredLanguages: locale.rLanguages)
        ethereumCryptoTypeView.actionControl.contentView.subtitleLabelView.text =
            R.string.localizable
                .ecdsaSelectionSubtitle(preferredLanguages: locale.rLanguages)
        ethereumCryptoTypeView.actionControl.invalidateLayout()

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()
    }

    @objc func actionExpand() {
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

    // swiftlint:disable function_body_length
    func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(Constants.contentBottomOffset)
        }

        sourceTypeViewContainer.addSubview(sourceTypeView)
        sourceTypeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(sourceTypeViewContainer)

        chainViewContainer.addSubview(chainView)
        chainView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(chainViewContainer)

        uploadViewContainer.addSubview(uploadView)
        uploadView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }
        contentView.stackView.addArrangedSubview(uploadViewContainer)

        warningContainerView.addSubview(warningImage)
        warningContainerView.addSubview(warningLabel)

        warningImage.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalTo(warningLabel)
        }

        warningLabel.snp.makeConstraints { make in
            make.leading.equalTo(warningImage.snp.trailing).offset(UIConstants.defaultOffset)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
        contentView.stackView.addArrangedSubview(warningContainerView)

        usernameTextFieldContainer.addSubview(usernameTextField)
        usernameTextField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(usernameTextFieldContainer)
        usernameLabelContainer.addSubview(usernameFooterLabel)
        usernameFooterLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(usernameLabelContainer)

        textViewContainer.addSubview(textTriangularedView)
        textTriangularedView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        textTriangularedView.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.textViewHeight)
            make.leading.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        textTriangularedView.addSubview(textPlaceholderLabel)
        textPlaceholderLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
        contentView.stackView.addArrangedSubview(textViewContainer)

        passwordContainerView.addSubview(passwordTextField)
        passwordTextField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(passwordContainerView)

        expandableControlContainerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.expandableViewHeight)
        }
        expandableControlContainerView.addSubview(expandableControlBorderedView)
        expandableControlBorderedView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        expandableControlBorderedView.addSubview(expandableControl)
        expandableControl.snp.makeConstraints { make in
            make.edges.equalTo(expandableControlContainerView)
        }
        contentView.stackView.addArrangedSubview(expandableControlContainerView)

        advancedStackView.addArrangedSubview(substrateCryptoTypeView)
        substrateCryptoTypeView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        substrateDerivationContainerView.addSubview(substrateDerivationPathField)
        substrateDerivationPathField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
        substrateDerivationContainerView.addSubview(substrateDerivationPathImage)
        substrateDerivationPathImage.snp.makeConstraints { make in
            make.size.equalTo(Constants.derivationImageSize)
            make.leading.equalTo(substrateDerivationPathField.snp.trailing).offset(Constants.dervationFieldToImageSpacing)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        advancedStackView.addArrangedSubview(substrateDerivationContainerView)
        substrateDerivationContainerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        advancedStackView.addArrangedSubview(substrateDerivationPathLabel)
        substrateDerivationPathLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.derivationPathLabelHeight)
        }

        advancedStackView.addArrangedSubview(ethereumCryptoTypeView)
        ethereumCryptoTypeView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        ethereumDerivationContainerView.addSubview(ethereumDerivationPathField)
        ethereumDerivationPathField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
        ethereumDerivationContainerView.addSubview(ethereumDerivationPathImage)
        ethereumDerivationPathImage.snp.makeConstraints { make in
            make.size.equalTo(Constants.derivationImageSize)
            make.leading.equalTo(ethereumDerivationPathField.snp.trailing).offset(Constants.dervationFieldToImageSpacing)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        advancedStackView.addArrangedSubview(ethereumDerivationContainerView)
        ethereumDerivationContainerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        advancedStackView.addArrangedSubview(ethereumDerivationPathLabel)
        ethereumDerivationPathLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.derivationPathLabelHeight)
        }

        advancedContainerView.addSubview(advancedStackView)
        advancedStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(advancedContainerView)

        addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().inset(UIConstants.bigOffset).constraint
        }
    }
}

extension AccountImportViewLayout {
    func handleKeyboard(frame: CGRect) {
        nextButton.snp.updateConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(frame.height + UIConstants.bigOffset)
        }
    }
}
