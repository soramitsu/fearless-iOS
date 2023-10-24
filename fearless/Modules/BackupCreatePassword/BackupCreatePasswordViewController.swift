import UIKit
import SoraFoundation
import SnapKit
import SoraUI

protocol BackupCreatePasswordViewOutput: AnyObject {
    func didLoad(view: BackupCreatePasswordViewInput)
    func didTapBackButton()
    func didTapContinueButton()
}

final class BackupCreatePasswordViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = BackupCreatePasswordViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: BackupCreatePasswordViewOutput

    private var passwordInputViewModel: InputViewModelProtocol?
    private var passwordConfirmViewModel: InputViewModelProtocol?

    private var inputCompleted: Bool {
        let passwordCompleted = passwordInputViewModel?.inputHandler.completed ?? false
        let confirmationCompleted = passwordConfirmViewModel?.inputHandler.completed ?? false
        let password = passwordInputViewModel?.inputHandler.normalizedValue
        let confirmationPassword = passwordConfirmViewModel?.inputHandler.normalizedValue

        let passwordsCompleted = (passwordCompleted && confirmationCompleted)
        let passwordMatched = password == confirmationPassword
        return passwordsCompleted && passwordMatched
    }

    // MARK: - Constructor

    init(
        output: BackupCreatePasswordViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = BackupCreatePasswordViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupAction()
        setupTextFields()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rootView.passwordTextField.animatedInputField.textField.becomeFirstResponder()
        rootView.passwordTextField.backgroundView.set(highlighted: true, animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods

    private func setupAction() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }
        rootView.continueButton.addAction { [weak self] in
            self?.output.didTapContinueButton()
        }
        rootView.confirmButton.addAction { [weak self] in
            self?.rootView.confirmButton.isChecked.toggle()
            self?.updateNextButton()
        }
        rootView.passwordTextField.rightButton.addAction { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.toggleSecurity(
                strongSelf.rootView.passwordTextField.animatedInputField.textField,
                eyeButton: strongSelf.rootView.passwordTextField.rightButton
            )
        }
        rootView.confirmPasswordTextField.rightButton.addAction { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.toggleSecurity(
                strongSelf.rootView.confirmPasswordTextField.animatedInputField.textField,
                eyeButton: strongSelf.rootView.confirmPasswordTextField.rightButton
            )
        }
        rootView.passwordTextField.animatedInputField.addAction(for: .touchUpInside) { [weak self] in
            self?.rootView.passwordTextField.backgroundView.set(highlighted: true, animated: true)
            if self?.rootView.confirmPasswordTextField.backgroundView.isHighlighted == true {
                self?.rootView.confirmPasswordTextField.backgroundView.set(highlighted: false, animated: true)
            }
        }
        rootView.confirmPasswordTextField.animatedInputField.addAction(for: .touchUpInside) { [weak self] in
            self?.rootView.confirmPasswordTextField.backgroundView.set(highlighted: true, animated: true)
            if self?.rootView.passwordTextField.backgroundView.isHighlighted == true {
                self?.rootView.passwordTextField.backgroundView.set(highlighted: false, animated: true)
            }
        }
    }

    private func setupTextFields() {
        rootView.passwordTextField.animatedInputField.delegate = self
        rootView.passwordTextField.animatedInputField.addTarget(
            self,
            action: #selector(actionPasswordInputChange),
            for: .editingChanged
        )

        rootView.confirmPasswordTextField.animatedInputField.delegate = self
        rootView.confirmPasswordTextField.animatedInputField.addTarget(
            self,
            action: #selector(actionConfirmationInputChange),
            for: .editingChanged
        )
    }

    private func updateNextButton() {
        let enabled = inputCompleted && rootView.confirmButton.isChecked
        rootView.continueButton.set(enabled: enabled)
    }

    private func toggleSecurity(_ textField: UITextField, eyeButton: UIButton) {
        let isSecure = !textField.isSecureTextEntry

        if isSecure {
            eyeButton.setImage(R.image.iconEye(), for: .normal)
        } else {
            eyeButton.setImage(R.image.iconNoEye(), for: .normal)
        }

        textField.isSecureTextEntry = isSecure
    }

    // MARK: - Private actions

    @objc private func actionPasswordInputChange() {
        if passwordInputViewModel?.inputHandler.value != rootView.passwordTextField.text {
            rootView.passwordTextField.text = passwordInputViewModel?.inputHandler.value
        }

        updateNextButton()
        rootView.setPassword(isMatched: inputCompleted)
    }

    @objc private func actionConfirmationInputChange() {
        if passwordConfirmViewModel?.inputHandler.value != rootView.confirmPasswordTextField.text {
            rootView.confirmPasswordTextField.text = passwordConfirmViewModel?.inputHandler.value
        }

        updateNextButton()
        rootView.setPassword(isMatched: inputCompleted)
    }
}

// MARK: - BackupCreatePasswordViewInput

extension BackupCreatePasswordViewController: BackupCreatePasswordViewInput {
    func setPassword(isMatched: Bool) {
        rootView.setPassword(isMatched: isMatched)
    }

    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        passwordInputViewModel = viewModel
        updateNextButton()
    }

    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) {
        passwordConfirmViewModel = viewModel
        updateNextButton()
    }
}

// MARK: - Localizable

extension BackupCreatePasswordViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - KeyboardViewAdoptable

extension BackupCreatePasswordViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { UIConstants.bigOffset }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

extension BackupCreatePasswordViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        if textField === rootView.passwordTextField.animatedInputField,
           passwordConfirmViewModel?.inputHandler.value.isEmpty == true {
            rootView.confirmPasswordTextField.animatedInputField.becomeFirstResponder()
            rootView.confirmPasswordTextField.backgroundView.set(highlighted: true, animated: false)
            rootView.passwordTextField.backgroundView.set(highlighted: false, animated: true)
        } else if textField === rootView.confirmPasswordTextField.animatedInputField,
                  inputCompleted, rootView.confirmButton.isChecked {
            textField.resignFirstResponder()
            output.didTapContinueButton()
        } else {
            textField.resignFirstResponder()
            rootView.confirmPasswordTextField.backgroundView.set(highlighted: false, animated: true)
        }

        return false
    }

    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === rootView.passwordTextField.animatedInputField {
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
