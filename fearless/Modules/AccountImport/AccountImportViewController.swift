import UIKit
import SoraKeystore
import SoraFoundation
import SoraUI

final class AccountImportViewController: UIViewController {
    private struct Constants {
        static let advancedFullHeight: CGFloat = 220.0
        static let advancedTruncHeight: CGFloat = 152.0
    }

    var presenter: AccountImportPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var sourceTypeView: BorderedSubtitleActionView!
    @IBOutlet private var usernameView: UIView!
    @IBOutlet private var usernameTextField: AnimatedTextField!
    @IBOutlet private var usernameFooterLabel: UILabel!
    @IBOutlet private var passwordView: TriangularedView!
    @IBOutlet private var passwordSeparatorView: UIView!
    @IBOutlet private var passwordTextField: AnimatedTextField!
    @IBOutlet private var textPlaceholderLabel: UILabel!
    @IBOutlet private var textView: UITextView!
    @IBOutlet private var nextButton: TriangularedButton!

    @IBOutlet private var textContainerView: UIView!
    @IBOutlet private var textContainerSeparatorView: UIView!

    @IBOutlet private var uploadView: DetailsTriangularedView!
    @IBOutlet private var uploadSeparatorView: UIView!

    @IBOutlet private var warningView: UIView!
    @IBOutlet private var warningLabel: UILabel!

    @IBOutlet var networkTypeView: BorderedSubtitleActionView!
    @IBOutlet var cryptoTypeView: BorderedSubtitleActionView!

    @IBOutlet var derivationPathView: TriangularedView!
    @IBOutlet var derivationPathLabel: UILabel!
    @IBOutlet var derivationPathField: UITextField!
    @IBOutlet var derivationPathImageView: UIImageView!

    @IBOutlet var advancedContainerView: UIView!
    @IBOutlet var advancedView: UIView!
    @IBOutlet var advancedControl: ExpandableActionControl!

    @IBOutlet var advancedContainerHeight: NSLayoutConstraint!

    private var derivationPathModel: InputViewModelProtocol?
    private var usernameViewModel: InputViewModelProtocol?
    private var passwordViewModel: InputViewModelProtocol?
    private var sourceViewModel: InputViewModelProtocol?

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(type: .push,
                                                        duration: 0.35,
                                                        subtype: .fromBottom,
                                                        curve: .easeOut)

    var advancedDismissalAnimator = TransitionAnimator(type: .push,
                                                       duration: 0.35,
                                                       subtype: .fromTop,
                                                       curve: .easeIn)

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

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }

        advancedContainerView.isHidden = !advancedControl.isActivated

        if let placeholder = derivationPathField.placeholder {
            let color = R.color.colorGray() ?? .gray
            let attributedPlaceholder = NSAttributedString(string: placeholder,
                                                           attributes: [.foregroundColor: color])
            derivationPathField.attributedPlaceholder = attributedPlaceholder
        }

        textView.tintColor = R.color.colorWhite()

        sourceTypeView.actionControl.addTarget(self,
                                               action: #selector(actionOpenSourceType),
                                               for: .valueChanged)

        cryptoTypeView.actionControl.addTarget(self,
                                               action: #selector(actionOpenCryptoType),
                                               for: .valueChanged)

        networkTypeView.actionControl.addTarget(self,
                                                action: #selector(actionOpenAddressType),
                                                for: .valueChanged)

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

        uploadView.delegate = self
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable
            .onboardingRestoreAccount(preferredLanguages: locale.rLanguages)
        sourceTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale.rLanguages)

        setupUsernamePlaceholder(for: locale)

        usernameFooterLabel.text = R.string.localizable
            .usernameSetupHint(preferredLanguages: locale.rLanguages)

        setupPasswordPlaceholder(for: locale)

        advancedControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)
        advancedControl.invalidateLayout()

        cryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonCryptoType(preferredLanguages: locale.rLanguages)
        cryptoTypeView.actionControl.invalidateLayout()

        derivationPathLabel.text = R.string.localizable
            .commonSecretDerivationPath(preferredLanguages: locale.rLanguages)

        networkTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonChooseNetwork(preferredLanguages: locale.rLanguages)
        networkTypeView.invalidateLayout()

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()

        uploadView.title = R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages)

        if !uploadView.isHidden {
            updateUploadView()
        }
    }

    private func setupUsernamePlaceholder(for locale: Locale) {
        usernameTextField.title = R.string.localizable
            .usernameSetupChooseTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupPasswordPlaceholder(for locale: Locale) {
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

        if let viewModel = derivationPathModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(derivationPathField.text?.isEmpty ?? true)
        }

        nextButton?.isEnabled = isEnabled
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

            let locale = localizationManager?.selectedLocale
            uploadView.subtitle = R.string.localizable.recoverJsonHint(preferredLanguages: locale?.rLanguages)
        }
    }

    @IBAction private func actionExpand() {
        stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !advancedControl.isActivated

        if advancedControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            derivationPathField.resignFirstResponder()

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

    @IBAction private func actionDerivationPathTextFieldChanged() {
        if derivationPathModel?.inputHandler.value != derivationPathField.text {
            derivationPathField.text = derivationPathModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc private func actionOpenSourceType() {
        if sourceTypeView.actionControl.isActivated {
            presenter.selectSourceType()
        }
    }

    @objc private func actionOpenCryptoType() {
        if cryptoTypeView.actionControl.isActivated {
            presenter.selectCryptoType()
        }
    }

    @objc private func actionOpenAddressType() {
        if networkTypeView.actionControl.isActivated {
            presenter.selectNetworkType()
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
            passwordSeparatorView.isHidden = true
            passwordTextField.text = nil
            passwordViewModel = nil

            derivationPathView.isHidden = false
            advancedContainerHeight.constant = Constants.advancedFullHeight

            uploadView.isHidden = true
            uploadSeparatorView.isHidden = true

            textContainerView.isHidden = false
            textContainerSeparatorView.isHidden = false

        case .seed:
            passwordView.isHidden = true
            passwordSeparatorView.isHidden = true
            passwordTextField.text = nil
            passwordViewModel = nil

            derivationPathView.isHidden = false
            advancedContainerHeight.constant = Constants.advancedFullHeight

            uploadView.isHidden = true
            uploadSeparatorView.isHidden = true

            textContainerView.isHidden = false
            textContainerSeparatorView.isHidden = false

        case .keystore:
            passwordView.isHidden = false
            passwordSeparatorView.isHidden = false

            derivationPathView.isHidden = true
            advancedContainerHeight.constant = Constants.advancedTruncHeight

            uploadView.isHidden = false
            uploadSeparatorView.isHidden = false

            textContainerView.isHidden = true
            textView.text = nil
            textContainerSeparatorView.isHidden = true
        }

        warningView.isHidden = true

        advancedControl.deactivate(animated: false)
        advancedContainerView.isHidden = true

        let locale = localizationManager?.selectedLocale ?? Locale.current

        sourceTypeView.actionControl.contentView.subtitleLabelView.text = type.titleForLocale(locale)

        cryptoTypeView.actionControl.contentView.invalidateLayout()
        cryptoTypeView.actionControl.invalidateLayout()
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

        cryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        cryptoTypeView.actionControl.showsImageIndicator = model.selectable
        cryptoTypeView.isUserInteractionEnabled = model.selectable

        if model.selectable {
            cryptoTypeView.applyEnabledStyle()
        } else {
            cryptoTypeView.applyDisabledStyle()
        }

        cryptoTypeView.actionControl.contentView.invalidateLayout()
        cryptoTypeView.actionControl.invalidateLayout()
    }

    func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>) {
        networkTypeView.actionControl.contentView.subtitleImageView.image = model.underlyingViewModel.icon
        networkTypeView.actionControl.contentView.subtitleLabelView.text = model.underlyingViewModel.title

        networkTypeView.actionControl.showsImageIndicator = model.selectable
        networkTypeView.isUserInteractionEnabled = model.selectable

        if model.selectable {
            networkTypeView.applyEnabledStyle()
        } else {
            networkTypeView.applyDisabledStyle()
        }

        networkTypeView.actionControl.contentView.invalidateLayout()
        networkTypeView.actionControl.invalidateLayout()

        warningView.isHidden = true
    }

    func setDerivationPath(viewModel: InputViewModelProtocol) {
        derivationPathModel = viewModel

        derivationPathField.placeholder = viewModel.placeholder
        derivationPathField.text = viewModel.inputHandler.value
        derivationPathImageView.image = nil
    }

    func setUploadWarning(message: String) {
        warningLabel.text = message
        warningView.isHidden = false
    }

    func didCompleteSourceTypeSelection() {
        sourceTypeView.actionControl.deactivate(animated: true)
    }

    func didCompleteCryptoTypeSelection() {
        cryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didCompleteAddressTypeSelection() {
        networkTypeView.actionControl.deactivate(animated: true)
    }

    func didValidateDerivationPath(_ status: FieldStatus) {
        derivationPathImageView.image = status.icon
    }
}

extension AccountImportViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        presenter.validateDerivationPath()

        return false
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let currentViewModel = derivationPathModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountImportViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool {
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

    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
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

extension AccountImportViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if textView.isFirstResponder {
                targetView = textView
            } else if usernameTextField.isFirstResponder {
                targetView = usernameView
            } else if passwordTextField.isFirstResponder {
                targetView = passwordView
            } else if derivationPathField.isFirstResponder {
                targetView = derivationPathView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(firstResponderView.frame,
                                                    from: firstResponderView.superview)

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
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

extension AccountImportViewController: DetailsTriangularedViewDelegate {
    func detailsViewDidSelectAction(_ details: DetailsTriangularedView) {
        presenter.activateUpload()
    }
}
