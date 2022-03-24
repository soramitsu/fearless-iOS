import UIKit
import SoraUI
import SoraFoundation

final class AccountImportViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountImportViewLayout

    private let presenter: AccountImportPresenterProtocol
    private var substrateDerivationPathModel: InputViewModelProtocol?
    private var ethereumDerivationPathModel: InputViewModelProtocol?
    private var usernameViewModel: InputViewModelProtocol?
    private var passwordViewModel: InputViewModelProtocol?
    private var sourceViewModel: InputViewModelProtocol?
    private var isFirstLayoutCompleted: Bool = false

    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    init(presenter: AccountImportPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AccountImportViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupActions()
        setupLocalization()
        setupActions()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        isFirstLayoutCompleted = true
    }
}

private extension AccountImportViewController {
    func setupActions() {
        rootView.usernameTextField.animatedInputField.delegate = self
        rootView.passwordTextField.animatedInputField.delegate = self
        rootView.substrateDerivationPathField.delegate = self
        rootView.ethereumDerivationPathField.delegate = self
        rootView.textView.delegate = self

        rootView.usernameTextField.animatedInputField.addTarget(self, action: #selector(actionNameTextFieldChanged), for: .editingChanged)
        rootView.passwordTextField.animatedInputField.addTarget(self, action: #selector(actionPasswordTextFieldChanged), for: .editingChanged)
        rootView.substrateDerivationPathField.addTarget(self, action: #selector(substrateTextFieldEditingChanged), for: .editingChanged)
        rootView.ethereumDerivationPathField.addTarget(self, action: #selector(ethereumTextFieldEditingChanged), for: .editingChanged)

        rootView.sourceTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenSourceType),
            for: .valueChanged
        )

        rootView.substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenCryptoType),
            for: .valueChanged
        )

        rootView.uploadView.addTarget(self, action: #selector(actionUpload), for: .touchUpInside)
        rootView.nextButton.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
    }

    func setupLocalization() {
        if isViewLoaded {
            rootView.locale = locale
            view.setNeedsLayout()
        }

        title = R.string.localizable.importWallet(preferredLanguages: locale.rLanguages)

        if !rootView.uploadViewContainer.isHidden {
            updateUploadView()
        }
    }

    func updateNextButton() {
        var isEnabled: Bool = true

        if let viewModel = sourceViewModel, viewModel.inputHandler.required {
            let uploadViewActive = !rootView.uploadViewContainer.isHidden && !(rootView.uploadView.subtitle?.isEmpty ?? false)
            let textViewActive = !rootView.textViewContainer.isHidden && !rootView.textView.text.isEmpty
            isEnabled = isEnabled && (uploadViewActive || textViewActive)
        }

        if let viewModel = usernameViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(rootView.usernameTextField.text?.isEmpty ?? true)
        }

        if let viewModel = passwordViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(rootView.passwordTextField.text?.isEmpty ?? true)
        }

        if let viewModel = substrateDerivationPathModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(rootView.substrateDerivationPathField.text?.isEmpty ?? true)
        }

        if let viewModel = ethereumDerivationPathModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(rootView.ethereumDerivationPathField.text?.isEmpty ?? true)
        }

        rootView.nextButton.set(enabled: isEnabled)
    }

    func updateUploadView() {
        if let viewModel = sourceViewModel, !viewModel.inputHandler.normalizedValue.isEmpty {
            rootView.uploadView.subtitleLabel?.textColor = R.color.colorWhite()
            rootView.uploadView.subtitle = viewModel.inputHandler.normalizedValue
        } else {
            rootView.uploadView.subtitleLabel?.textColor = R.color.colorLightGray()

            rootView.uploadView.subtitle = R.string.localizable.recoverJsonHint(preferredLanguages: locale.rLanguages)
        }
    }

    @objc func actionNameTextFieldChanged() {
        if usernameViewModel?.inputHandler.value != rootView.usernameTextField.text {
            rootView.usernameTextField.text = usernameViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc func actionPasswordTextFieldChanged() {
        if passwordViewModel?.inputHandler.value != rootView.passwordTextField.text {
            rootView.passwordTextField.text = passwordViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc func substrateTextFieldEditingChanged() {
        if substrateDerivationPathModel?.inputHandler.value != rootView.substrateDerivationPathField.text {
            rootView.substrateDerivationPathField.text = substrateDerivationPathModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc func ethereumTextFieldEditingChanged() {
        if ethereumDerivationPathModel?.inputHandler.value != rootView.ethereumDerivationPathField.text {
            rootView.ethereumDerivationPathField.text = ethereumDerivationPathModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc func actionUpload() {
        presenter.activateUpload()
    }

    @objc func actionOpenSourceType() {
        if rootView.sourceTypeView.actionControl.isActivated {
            presenter.selectSourceType()
        }
    }

    @objc func actionOpenCryptoType() {
        if rootView.substrateCryptoTypeView.actionControl.isActivated {
            presenter.selectCryptoType()
        }
    }

    @objc func actionNext() {
        presenter.proceed()
    }
}

extension AccountImportViewController: AccountImportViewProtocol {
    func show(chainType: AccountCreateChainType) {
        rootView.set(chainType: chainType)
    }

    func setSource(type: AccountImportSource, selectable: Bool) {
        switch type {
        case .mnemonic, .seed:
            passwordViewModel = nil

            rootView.setup(isJson: false)
        case .keystore:
            rootView.setup(isJson: true)
        }

        rootView.warningContainerView.isHidden = true

        rootView.expandableControl.deactivate(animated: false)
        rootView.advancedContainerView.isHidden = true

        rootView.sourceTypeView.actionControl.contentView.subtitleLabelView.text = type.titleForLocale(locale)
        rootView.sourceTypeView.isUserInteractionEnabled = selectable
        rootView.uploadView.title =
            selectable ? R.string.localizable.importSubstrateRecoveryJson(preferredLanguages: locale.rLanguages) :
            R.string.localizable.importEthereumRecoveryJson(preferredLanguages: locale.rLanguages)

        rootView.substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        rootView.substrateCryptoTypeView.actionControl.invalidateLayout()
        rootView.substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel

        if !rootView.uploadViewContainer.isHidden {
            updateUploadView()
        } else {
            rootView.textView.text = viewModel.inputHandler.value
            rootView.textPlaceholderLabel.text = viewModel.placeholder
        }

        rootView.updateTextViewPlaceholder()
        updateNextButton()
    }

    func setName(viewModel: InputViewModelProtocol) {
        usernameViewModel = viewModel

        rootView.usernameTextField.text = viewModel.inputHandler.value
        rootView.usernameTextField.isUserInteractionEnabled = viewModel.inputHandler.value.isEmpty
        updateNextButton()
    }

    func setPassword(viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel

        rootView.passwordTextField.text = viewModel.inputHandler.value
        rootView.passwordTextField.isUserInteractionEnabled = viewModel.inputHandler.value.isEmpty

        updateNextButton()
    }

    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>) {
        let title = "\(model.underlyingViewModel.title) | \(model.underlyingViewModel.subtitle)"

        rootView.substrateCryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        if model.selectable {
            rootView.substrateCryptoTypeView.enable()
        } else {
            rootView.substrateCryptoTypeView.disable()
        }

        rootView.substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        rootView.substrateCryptoTypeView.actionControl.invalidateLayout()
    }

    func bind(substrateViewModel: InputViewModelProtocol) {
        substrateDerivationPathModel = substrateViewModel

        rootView.substrateDerivationPathField.text = substrateViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.substrateSecretDerivationPath(
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        rootView.substrateDerivationPathField.attributedPlaceholder = attributedPlaceholder
        rootView.substrateDerivationPathLabel.text = R.string.localizable
            .example(substrateViewModel.placeholder, preferredLanguages: locale.rLanguages)
    }

    func bind(ethereumViewModel: InputViewModelProtocol) {
        ethereumDerivationPathModel = ethereumViewModel

        rootView.ethereumDerivationPathField.text = ethereumViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.ethereumSecretDerivationPath(
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        rootView.ethereumDerivationPathField.attributedPlaceholder = attributedPlaceholder
        rootView.ethereumDerivationPathLabel.text = R.string.localizable
            .example(ethereumViewModel.placeholder, preferredLanguages: locale.rLanguages)
    }

    func setUploadWarning(message: String) {
        rootView.warningLabel.text = message
        rootView.warningContainerView.isHidden = false
    }

    func didCompleteSourceTypeSelection() {
        rootView.sourceTypeView.actionControl.deactivate(animated: true)
    }

    func didCompleteCryptoTypeSelection() {
        rootView.substrateCryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didValidateSubstrateDerivationPath(_ status: FieldStatus) {
        rootView.substrateDerivationPathImage.image = status.icon
    }

    func didValidateEthereumDerivationPath(_ status: FieldStatus) {
        rootView.ethereumDerivationPathImage.image = status.icon
    }
}

extension AccountImportViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == rootView.substrateDerivationPathField {
            presenter.validateSubstrateDerivationPath()
        } else if textField == rootView.ethereumDerivationPathField {
            presenter.validateEthereumDerivationPath()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()
        if textField == rootView.substrateDerivationPathField {
            presenter.validateSubstrateDerivationPath()
        } else if textField == rootView.ethereumDerivationPathField {
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
        var viewModel: InputViewModelProtocol?

        if textField === rootView.usernameTextField.animatedInputField {
            viewModel = usernameViewModel
        } else if textField === rootView.passwordTextField.animatedInputField {
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

        rootView.updateTextViewPlaceholder()
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
    var targetBottomConstraint: NSLayoutConstraint? { nil }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat {
        if bottomInset > 0.0 {
            return -view.safeAreaInsets.bottom + UIConstants.bigOffset
        } else {
            return UIConstants.bigOffset
        }
    }

    func updateWhileKeyboardFrameChanging(frame: CGRect) {
        rootView.handleKeyboard(frame: frame)
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
        if field == rootView.substrateDerivationPathField {
            return substrateDerivationPathModel
        } else if field == rootView.ethereumDerivationPathField {
            return ethereumDerivationPathModel
        }
        return nil
    }
}
