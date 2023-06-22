import UIKit
import SoraFoundation
import SoraUI

protocol BackupPasswordViewOutput: AnyObject {
    func didLoad(view: BackupPasswordViewInput)
    func didBackButtonTapped()
    func didContinueButtonTapped()
    func passwordDidChainged(password: String)
}

final class BackupPasswordViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupPasswordViewLayout

    // MARK: Private properties

    private let output: BackupPasswordViewOutput

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

    // MARK: - Private methods

    private func configure() {
        rootView.passwordTextField.animatedInputField.delegate = self
    }

    private func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }
        rootView.continueButton.addAction { [weak self] in
            self?.output.didContinueButtonTapped()
        }
    }
}

// MARK: - BackupPasswordViewInput

extension BackupPasswordViewController: BackupPasswordViewInput {
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

    func animatedTextField(_ textField: SoraUI.AnimatedTextField, shouldChangeCharactersIn _: NSRange, replacementString _: String) -> Bool {
        guard let text = textField.text else {
            return false
        }
        output.passwordDidChainged(password: text)
        rootView.continueButton.isEnabled = text.isNotEmpty
        return true
    }
}
