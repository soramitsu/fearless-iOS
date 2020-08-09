import UIKit
import SoraKeystore
import SoraFoundation
import SoraUI

final class AccountImportViewController: UIViewController {
    var presenter: AccountImportPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var sourceTypeView: BorderedSubtitleActionView!
    @IBOutlet private var usernameView: UIView!
    @IBOutlet private var usernameTextField: UITextField!
    @IBOutlet private var usernameFooterLabel: UILabel!
    @IBOutlet private var passwordView: TriangularedView!
    @IBOutlet private var passwordSeparatorView: UIView!
    @IBOutlet private var passwordTextField: UITextField!
    @IBOutlet private var textPlaceholderLabel: UILabel!
    @IBOutlet private var textView: UITextView!
    @IBOutlet private var nextButton: TriangularedButton!

    @IBOutlet var networkTypeView: BorderedSubtitleActionView!
    @IBOutlet var cryptoTypeView: BorderedSubtitleActionView!

    @IBOutlet var derivationPathView: TriangularedView!
    @IBOutlet var derivationPathLabel: UILabel!
    @IBOutlet var derivationPathField: UITextField!
    @IBOutlet var derivationPathImageView: UIImageView!

    @IBOutlet var advancedContainerView: UIView!
    @IBOutlet var advancedView: UIView!
    @IBOutlet var advancedControl: ExpandableActionControl!

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
        setupNavigationItem()
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
    }

    private func setupNavigationItem() {
        let infoItem = UIBarButtonItem(image: R.image.iconScanQr(),
                                       style: .plain,
                                       target: self,
                                       action: #selector(actionOpenScanQr))
        navigationItem.rightBarButtonItem = infoItem
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
    }

    private func setupUsernamePlaceholder(for locale: Locale) {
        let color = R.color.colorGray() ?? .gray
        let placeholder = R.string.localizable.usernameSetupChooseTitle(preferredLanguages: locale.rLanguages)
        let attributedPlaceholder = NSAttributedString(string: placeholder,
                                                   attributes: [.foregroundColor: color])

        usernameTextField.attributedPlaceholder = attributedPlaceholder
    }

    private func setupPasswordPlaceholder(for locale: Locale) {
        let color = R.color.colorGray() ?? .gray
        let placeholder = R.string.localizable
            .accountImportPasswordPlaceholder(preferredLanguages: locale.rLanguages)
        let attributedPlaceholder = NSAttributedString(string: placeholder,
                                                   attributes: [.foregroundColor: color])

        passwordTextField.attributedPlaceholder = attributedPlaceholder
    }

    private func updateNextButton() {
        var isEnabled: Bool = true

        if let viewModel = sourceViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !textView.text.isEmpty
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

    @objc private func actionOpenScanQr() {
        presenter.activateQrScan()
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
            presenter.selectAddressType()
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

            advancedView.isHidden = false
        case .seed:
            passwordView.isHidden = true
            passwordSeparatorView.isHidden = true
            passwordTextField.text = nil
            passwordViewModel = nil

            advancedView.isHidden = false
        case .keystore:
            passwordView.isHidden = false
            passwordSeparatorView.isHidden = false

            advancedView.isHidden = true
            advancedControl.deactivate(animated: false)
            advancedContainerView.isHidden = true
        }
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel

        textPlaceholderLabel.text = viewModel.placeholder
        textView.text = viewModel.inputHandler.value

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

    func setSelectedSource(model: TitleWithSubtitleViewModel) {
        sourceTypeView.actionControl.contentView.subtitleLabelView.text = model.title

        cryptoTypeView.actionControl.contentView.invalidateLayout()
        cryptoTypeView.actionControl.invalidateLayout()
    }

    func setSelectedCrypto(model: TitleWithSubtitleViewModel) {
        let title = "\(model.title) | \(model.subtitle)"

        cryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        cryptoTypeView.actionControl.contentView.invalidateLayout()
        cryptoTypeView.actionControl.invalidateLayout()
    }

    func setSelectedNetwork(model: IconWithTitleViewModel) {
        networkTypeView.actionControl.contentView.subtitleImageView.image = model.icon
        networkTypeView.actionControl.contentView.subtitleLabelView.text = model.title

        networkTypeView.actionControl.contentView.invalidateLayout()
        networkTypeView.actionControl.invalidateLayout()
    }

    func setDerivationPath(viewModel: InputViewModelProtocol) {
        derivationPathModel = viewModel

        derivationPathField.placeholder = viewModel.placeholder
        derivationPathField.text = viewModel.inputHandler.value
        derivationPathImageView.image = nil
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
        textField.resignFirstResponder()

        if textField === derivationPathField {
            presenter.validateDerivationPath()
        }

        return false
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === usernameTextField {
            viewModel = usernameViewModel
        } else if textField === passwordTextField {
            viewModel = passwordViewModel
        } else {
            viewModel = derivationPathModel
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
        if text.rangeOfCharacter(from: CharacterSet.newlines) != nil {
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
