import UIKit
import SoraFoundation
import SoraUI
import SnapKit

protocol BackupPasswordViewOutput: AnyObject {
    func didLoad(view: BackupPasswordViewInput)
    func didBackButtonTapped()
    func didContinueButtonTapped()
}

final class BackupPasswordViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupPasswordViewLayout

    // MARK: Private properties

    private let output: BackupPasswordViewOutput

    private var passwordInputViewModel: InputViewModelProtocol?

    // MARK: - Constructor

    init(
        output: BackupPasswordViewOutput,
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
        view = BackupPasswordViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
        configure()
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
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.passwordTextField.animatedInputField.delegate = self
        rootView.passwordTextField.animatedInputField.addTarget(
            self,
            action: #selector(actionPasswordInputChange),
            for: .editingChanged
        )
    }

    private func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }
        rootView.continueButton.addAction { [weak self] in
            self?.output.didContinueButtonTapped()
        }
        rootView.passwordTextField.rightButton.addAction { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.toggleSecurity(
                strongSelf.rootView.passwordTextField.animatedInputField.textField,
                eyeButton: strongSelf.rootView.passwordTextField.rightButton
            )
        }
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

        let enabled = passwordInputViewModel?.inputHandler.completed ?? false
        rootView.continueButton.set(enabled: enabled)
    }
}

// MARK: - BackupPasswordViewInput

extension BackupPasswordViewController: BackupPasswordViewInput {
    func setPasswordInputViewModel(_ viewModel: SoraFoundation.InputViewModelProtocol) {
        passwordInputViewModel = viewModel
    }

    func didReceive(walletName: String) {
        rootView.bind(walletName: walletName)
    }
}

// MARK: - Localizable

extension BackupPasswordViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - AnimatedTextFieldDelegate

extension BackupPasswordViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: SoraUI.AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        rootView.passwordTextField.backgroundView.set(highlighted: false, animated: false)
        return false
    }

    func animatedTextField(
        _ textField: SoraUI.AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let currentViewModel = passwordInputViewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }
}

// MARK: - KeyboardViewAdoptable

extension BackupPasswordViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { UIConstants.bigOffset }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
