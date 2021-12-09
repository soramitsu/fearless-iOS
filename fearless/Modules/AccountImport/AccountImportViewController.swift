import UIKit
import SoraKeystore
import SoraFoundation
import SoraUI

final class AccountImportViewController: UIViewController {
    private enum Constants {
        static let advancedFullHeight: CGFloat = 321.0
        static let advancedTruncHeight: CGFloat = 84.0
        static let verticalSpacing: CGFloat = 16.0
        static let nextButtonBottomInset: CGFloat = 16
    }

    var presenter: AccountImportPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var sourceTypeView: BorderedSubtitleActionView!
    @IBOutlet private var usernameView: UIView!
    @IBOutlet private var usernameTextField: AnimatedTextField!
    @IBOutlet private var usernameFooterLabel: UILabel!
    @IBOutlet private var passwordView: TriangularedView!
    @IBOutlet private var passwordTextField: AnimatedTextField!
    @IBOutlet private var textPlaceholderLabel: UILabel!
    @IBOutlet private var textView: UITextView!
    @IBOutlet private var nextButton: TriangularedButton!

    @IBOutlet private var textContainerView: UIView!

    @IBOutlet private var uploadView: DetailsTriangularedView!

    @IBOutlet private var warningView: UIView!
    @IBOutlet private var warningLabel: UILabel!
    @IBOutlet private var nextButtonBottom: NSLayoutConstraint!

    @IBOutlet var substrateCryptoTypeView: BorderedSubtitleActionView!

    @IBOutlet var ethereumCryptoTypeView: TriangularedTwoLabelView!

    @IBOutlet var substrateDerivationPathLabel: UILabel!
    @IBOutlet var substrateDerivationPathField: UITextField!
    @IBOutlet var substrateDerivationPathImageView: UIImageView!

    @IBOutlet var ethereumDerivationPathImageView: UIImageView!
    @IBOutlet var ethereumDerivationPathField: UITextField!
    @IBOutlet var ethereumDerivationPathLabel: UILabel!

    @IBOutlet var advancedContainerView: UIView!
    @IBOutlet var advancedControl: ExpandableActionControl!

    @IBOutlet var advancedContainerHeight: NSLayoutConstraint!

    private var substrateDerivationPathModel: InputViewModelProtocol?
    private var ethereumDerivationPathModel: InputViewModelProtocol?
    private var usernameViewModel: InputViewModelProtocol?
    private var passwordViewModel: InputViewModelProtocol?
    private var sourceViewModel: InputViewModelProtocol?
    private var isFirstLayoutCompleted: Bool = false

    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

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

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        updateTextViewPlaceholder()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        isFirstLayoutCompleted = true
    }

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }

        stackView.setCustomSpacing(Constants.verticalSpacing, after: sourceTypeView)
        stackView.setCustomSpacing(Constants.verticalSpacing, after: uploadView)

        advancedContainerView.isHidden = !advancedControl.isActivated

        textView.tintColor = R.color.colorWhite()

        sourceTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenSourceType),
            for: .valueChanged
        )

        substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenCryptoType),
            for: .valueChanged
        )

        usernameTextField.textField.returnKeyType = .done
        usernameTextField.textField.textContentType = .nickname
        usernameTextField.textField.autocapitalizationType = .none
        usernameTextField.textField.autocorrectionType = .no
        usernameTextField.textField.spellCheckingType = .no

        passwordTextField.textField.returnKeyType = .done
        passwordTextField.textField.textContentType = .password
        passwordTextField.textField.autocapitalizationType = .none
        passwordTextField.textField.autocorrectionType = .no
        passwordTextField.textField.spellCheckingType = .no
        passwordTextField.textField.isSecureTextEntry = true

        usernameTextField.delegate = self
        passwordTextField.delegate = self

        uploadView.addTarget(self, action: #selector(actionUpload), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable
            .onboardingRestoreAccount(preferredLanguages: locale.rLanguages)
        sourceTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale.rLanguages)

        setupUsernamePlaceholder()

        usernameFooterLabel.text = R.string.localizable
            .usernameSetupHint(preferredLanguages: locale.rLanguages)

        setupPasswordPlaceholder()

        advancedControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)
        advancedControl.invalidateLayout()

        substrateCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .substrateCryptoType(preferredLanguages: locale.rLanguages)
        substrateCryptoTypeView.actionControl.invalidateLayout()
        ethereumCryptoTypeView.twoVerticalLabelView.titleLabel.text = R.string.localizable
            .ethereumCryptoType(preferredLanguages: locale.rLanguages)
        substrateCryptoTypeView.actionControl.invalidateLayout()

        substrateDerivationPathLabel.text = R.string.localizable
            .substrateSecretDerivationPath(preferredLanguages: locale.rLanguages)
        ethereumDerivationPathLabel.text = R.string.localizable
            .ethereumSecretDerivationPath(preferredLanguages: locale.rLanguages)

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()

        uploadView.title = R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages)

        if !uploadView.isHidden {
            updateUploadView()
        }
    }

    private func setupUsernamePlaceholder() {
        usernameTextField.title = R.string.localizable
            .accountInfoNameTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupPasswordPlaceholder() {
        passwordTextField.title = R.string.localizable
            .accountImportPasswordPlaceholder(preferredLanguages: locale.rLanguages)
    }

    private func updateNextButton() {
        var isEnabled: Bool = true

        if let viewModel = sourceViewModel, viewModel.inputHandler.required {
            let uploadViewActive = !uploadView.isHidden && !(uploadView.subtitle?.isEmpty ?? false)
            let textViewActive = !textContainerView.isHidden && !textView.text.isEmpty
            isEnabled = isEnabled && (uploadViewActive || textViewActive)
        }

        if let viewModel = usernameViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(usernameTextField.text?.isEmpty ?? true)
        }

        if let viewModel = passwordViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(passwordTextField.text?.isEmpty ?? true)
        }

        if let viewModel = substrateDerivationPathModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(substrateDerivationPathField.text?.isEmpty ?? true)
        }

        if let viewModel = ethereumDerivationPathModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(ethereumDerivationPathField.text?.isEmpty ?? true)
        }

        nextButton?.set(enabled: isEnabled)
    }

    private func updateTextViewPlaceholder() {
        textPlaceholderLabel.isHidden = !textView.text.isEmpty
    }

    private func updateUploadView() {
        if let viewModel = sourceViewModel, !viewModel.inputHandler.normalizedValue.isEmpty {
            uploadView.subtitleLabel?.textColor = R.color.colorWhite()
            uploadView.subtitle = viewModel.inputHandler.normalizedValue
        } else {
            uploadView.subtitleLabel?.textColor = R.color.colorLightGray()

            uploadView.subtitle = R.string.localizable.recoverJsonHint(preferredLanguages: locale.rLanguages)
        }
    }

    @IBAction private func actionExpand() {
        stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !advancedControl.isActivated

        if advancedControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            substrateDerivationPathField.resignFirstResponder()
            ethereumDerivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    @IBAction private func actionNameTextFieldChanged() {
        if usernameViewModel?.inputHandler.value != usernameTextField.text {
            usernameTextField.text = usernameViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @IBAction private func actionPasswordTextFieldChanged() {
        if passwordViewModel?.inputHandler.value != passwordTextField.text {
            passwordTextField.text = passwordViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @IBAction private func substrateTextFieldEditingChanged() {
        if substrateDerivationPathModel?.inputHandler.value != substrateDerivationPathField.text {
            substrateDerivationPathField.text = substrateDerivationPathModel?.inputHandler.value
        }

        updateNextButton()
    }

    @IBAction func ethereumTextFieldEditingChanged() {
        if ethereumDerivationPathModel?.inputHandler.value != ethereumDerivationPathField.text {
            ethereumDerivationPathField.text = ethereumDerivationPathModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc private func actionUpload() {
        presenter.activateUpload()
    }

    @objc private func actionOpenSourceType() {
        if sourceTypeView.actionControl.isActivated {
            presenter.selectSourceType()
        }
    }

    @objc private func actionOpenCryptoType() {
        if substrateCryptoTypeView.actionControl.isActivated {
            presenter.selectCryptoType()
        }
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }
}

extension AccountImportViewController: AccountImportViewProtocol {
    func setSource(type: AccountImportSource) {
        switch type {
        case .mnemonic:
            passwordView.isHidden = true
            passwordTextField.text = nil
            passwordViewModel = nil

            advancedContainerView.subviews.forEach { $0.isHidden = false }
            advancedContainerHeight.constant = Constants.advancedFullHeight

            uploadView.isHidden = true

            textContainerView.isHidden = false

        case .seed:
            passwordView.isHidden = true
            passwordTextField.text = nil
            passwordViewModel = nil

            advancedContainerView.subviews.forEach { $0.isHidden = false }
            advancedContainerHeight.constant = Constants.advancedFullHeight

            uploadView.isHidden = true

            textContainerView.isHidden = false

        case .keystore:
            passwordView.isHidden = false

            advancedContainerView.subviews.forEach { $0.isHidden = true }
            advancedContainerHeight.constant = Constants.advancedTruncHeight

            uploadView.isHidden = false

            textContainerView.isHidden = true
            textView.text = nil
        }

        warningView.isHidden = true

        advancedControl.deactivate(animated: false)
        advancedContainerView.isHidden = true

        sourceTypeView.actionControl.contentView.subtitleLabelView.text = type.titleForLocale(locale)

        substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        substrateCryptoTypeView.actionControl.invalidateLayout()
        ethereumCryptoTypeView.twoVerticalLabelView.invalidateLayout()
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel

        if !uploadView.isHidden {
            updateUploadView()
        } else {
            textPlaceholderLabel.text = viewModel.placeholder
            textView.text = viewModel.inputHandler.value
        }

        updateTextViewPlaceholder()
        updateNextButton()
    }

    func setName(viewModel: InputViewModelProtocol) {
        usernameViewModel = viewModel

        usernameTextField.text = viewModel.inputHandler.value

        updateNextButton()
    }

    func setPassword(viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel

        passwordTextField.text = viewModel.inputHandler.value

        updateNextButton()
    }

    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>) {
        let title = "\(model.underlyingViewModel.title) | \(model.underlyingViewModel.subtitle)"

        substrateCryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        substrateCryptoTypeView.actionControl.showsImageIndicator = model.selectable
        substrateCryptoTypeView.isUserInteractionEnabled = model.selectable

        if model.selectable {
            substrateCryptoTypeView.applyEnabledStyle()
        } else {
            substrateCryptoTypeView.applyDisabledStyle()
        }

        substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        substrateCryptoTypeView.actionControl.invalidateLayout()
    }

    func bind(substrateViewModel: InputViewModelProtocol) {
        substrateDerivationPathModel = substrateViewModel

        substrateDerivationPathField.text = substrateViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.example(
                substrateViewModel.placeholder,
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        substrateDerivationPathField.attributedPlaceholder = attributedPlaceholder
    }

    func bind(ethereumViewModel: InputViewModelProtocol) {
        ethereumDerivationPathModel = ethereumViewModel

        ethereumDerivationPathField.text = ethereumViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.example(
                ethereumViewModel.placeholder,
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        ethereumDerivationPathField.attributedPlaceholder = attributedPlaceholder
    }

    func setUploadWarning(message: String) {
        warningLabel.text = message
        warningView.isHidden = false
    }

    func didCompleteSourceTypeSelection() {
        sourceTypeView.actionControl.deactivate(animated: true)
    }

    func didCompleteCryptoTypeSelection() {
        substrateCryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didValidateSubstrateDerivationPath(_ status: FieldStatus) {
        substrateDerivationPathImageView.image = status.icon
    }

    func didValidateEthereumDerivationPath(_ status: FieldStatus) {
        ethereumDerivationPathImageView.image = status.icon
    }
}

extension AccountImportViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == substrateDerivationPathField {
            presenter.validateSubstrateDerivationPath()
        } else if textField == ethereumDerivationPathField {
            presenter.validateEthereumDerivationPath()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()
        if textField == substrateDerivationPathField {
            presenter.validateSubstrateDerivationPath()
        } else if textField == ethereumDerivationPathField {
            presenter.validateEthereumDerivationPath()
        }
        return false
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = self.viewModel(for: textField) else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountImportViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === usernameTextField {
            viewModel = usernameViewModel
        } else {
            viewModel = passwordViewModel
        }

        guard let currentViewModel = viewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountImportViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView.text != sourceViewModel?.inputHandler.value {
            textView.text = sourceViewModel?.inputHandler.value
        }

        updateTextViewPlaceholder()
        updateNextButton()
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if text == String.returnKey {
            textView.resignFirstResponder()
            return false
        }

        guard let model = sourceViewModel else {
            return false
        }

        let shouldApply = model.inputHandler.didReceiveReplacement(text, for: range)

        if !shouldApply, textView.text != model.inputHandler.value {
            textView.text = model.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountImportViewController: KeyboardViewAdoptable {
    var targetBottomConstraint: NSLayoutConstraint? { nextButtonBottom }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat {
        if bottomInset > 0.0 {
            return -view.safeAreaInsets.bottom + Constants.nextButtonBottomInset
        } else {
            return Constants.nextButtonBottomInset
        }
    }
}

extension AccountImportViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

private extension AccountImportViewController {
    func viewModel(for field: UITextField) -> InputViewModelProtocol? {
        if field == substrateDerivationPathField {
            return substrateDerivationPathModel
        } else if field == ethereumDerivationPathField {
            return ethereumDerivationPathModel
        }
        return nil
    }
}
