import UIKit
import SoraUI
import SoraFoundation

final class AccountExportPasswordViewController: UIViewController {
    private struct Constants {
        static let bottomOffset: CGFloat = 8.0
    }

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var typeView: BorderedSubtitleActionView!
    @IBOutlet private var hintLabel: UILabel!
    @IBOutlet private var passwordInputField: AnimatedTextField!
    @IBOutlet private var passwordConfirmField: AnimatedTextField!
    @IBOutlet private var actionButton: TriangularedButton!
    @IBOutlet private var contentBottom: NSLayoutConstraint!
    @IBOutlet private var passwordInputEye: RoundedButton!
    @IBOutlet private var passwordConfirmEye: RoundedButton!
    private var errorView: ImageWithTitleView?

    var presenter: AccountExportPasswordPresenterProtocol!

    var keyboardHandler: KeyboardHandler?

    private var passwordInputViewModel: InputViewModelProtocol?
    private var passwordConfirmViewModel: InputViewModelProtocol?

    var inputCompleted: Bool {
        let passwordCompleted = passwordInputViewModel?.inputHandler.completed ?? false
        let confirmationCompleted = passwordConfirmViewModel?.inputHandler.completed ?? false

        return passwordCompleted && confirmationCompleted
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTextFields()

        updateNextButton()

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

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.commonExport(preferredLanguages: locale?.rLanguages)

        hintLabel.text = R.string.localizable.accountExportJsonHint(preferredLanguages: locale?.rLanguages)

        typeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale?.rLanguages)

        typeView.actionControl.contentView.subtitleLabelView.text = R.string.localizable
            .importRecoveryJson(preferredLanguages: locale?.rLanguages)

        passwordInputField.title = R.string.localizable
            .commonSetPassword(preferredLanguages: locale?.rLanguages)

        passwordConfirmField.title = R.string.localizable
            .commonConfirmPassword(preferredLanguages: locale?.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale?.rLanguages)
    }

    private func setupTextFields() {
        passwordInputField.textField.isSecureTextEntry = true
        passwordInputField.textField.returnKeyType = .done
        passwordInputField.delegate = self
        passwordInputField.addTarget(self,
                                     action: #selector(actionPasswordInputChange),
                                     for: .editingChanged)

        passwordConfirmField.textField.isSecureTextEntry = true
        passwordConfirmField.textField.returnKeyType = .done
        passwordConfirmField.delegate = self
        passwordConfirmField.addTarget(self,
                                       action: #selector(actionConfirmationInputChange),
                                       for: .editingChanged)
    }

    private func setupErrorView() {
        let view = ImageWithTitleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)

        view.iconImage = R.image.iconError()
        view.titleColor = R.color.colorWhite()
        view.titleFont = UIFont.p2Paragraph

        view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor,
                                  constant: -Constants.bottomOffset).isActive = true

        errorView = view

        updateBottomConstraint()
    }

    private func clearErrorView() {
        errorView?.removeFromSuperview()
        errorView = nil
    }

    private func updateBottomConstraint() {
        let offset: CGFloat

        if let errorView = errorView {
            offset = errorView.intrinsicContentSize.height + 2.0 * Constants.bottomOffset
        } else {
            offset = Constants.bottomOffset
        }

        contentBottom.constant = offset
        view.setNeedsLayout()
    }

    private func updateNextButton() {
        actionButton.isEnabled = inputCompleted
    }

    private func toggleSecurity(_ textField: UITextField, eyeButton: RoundedButton) {
        let isSecure = !textField.isSecureTextEntry

        if isSecure {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconEye()
        } else {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconNoEye()
        }

        textField.isSecureTextEntry = isSecure
    }

    @objc private func actionPasswordInputChange() {
        if passwordInputViewModel?.inputHandler.value != passwordInputField.text {
            passwordInputField.text = passwordInputViewModel?.inputHandler.value
        }

        updateNextButton()

        if errorView != nil {
            clearErrorView()
        }
    }

    @objc private func actionConfirmationInputChange() {
        if passwordConfirmViewModel?.inputHandler.value != passwordConfirmField.text {
            passwordConfirmField.text = passwordConfirmViewModel?.inputHandler.value
        }

        updateNextButton()

        if errorView != nil {
            clearErrorView()
        }
    }

    @IBAction private func actionPasswordInputEyeToggle() {
        toggleSecurity(passwordInputField.textField, eyeButton: passwordInputEye)
    }

    @IBAction private func actionPasswordConfirmEyeToggle() {
        toggleSecurity(passwordConfirmField.textField, eyeButton: passwordConfirmEye)
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }
}

extension AccountExportPasswordViewController: AccountExportPasswordViewProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        self.passwordInputViewModel = viewModel
        updateNextButton()
    }

    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) {
        self.passwordConfirmViewModel = viewModel
        updateNextButton()
    }

    func set(error: AccountExportPasswordError) {
        if errorView == nil {
            setupErrorView()
        }

        let content = error.toErrorContent(for: localizationManager?.selectedLocale)
        errorView?.title = content.message
    }
}

extension AccountExportPasswordViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        if textField === passwordInputField, passwordConfirmViewModel?.inputHandler.value.isEmpty == true {
            passwordConfirmField.becomeFirstResponder()
        } else if textField === passwordConfirmField, inputCompleted {
            textField.resignFirstResponder()

            presenter.proceed()
        } else {
            textField.resignFirstResponder()
        }

        return false
    }

    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === passwordInputField {
            viewModel = passwordInputViewModel
        } else {
            viewModel = passwordConfirmViewModel
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

extension AccountExportPasswordViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if passwordInputField.isFirstResponder {
                targetView = passwordInputField
            } else if passwordConfirmField.isFirstResponder {
                targetView = passwordConfirmField
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

extension AccountExportPasswordViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
