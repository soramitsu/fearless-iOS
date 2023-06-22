import UIKit
import SoraFoundation
import SoraUI

protocol BackupWalletNameViewOutput: AnyObject {
    func didLoad(view: BackupWalletNameViewInput)
    func didBackButtonTapped()
    func didContinueButtonTapped()
    func nameDidChainged(name: String)
}

final class BackupWalletNameViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupWalletNameViewLayout

    // MARK: Private properties

    private let output: BackupWalletNameViewOutput

    // MARK: - Constructor

    init(
        output: BackupWalletNameViewOutput,
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
        view = BackupWalletNameViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.nameTextField.animatedInputField.delegate = self
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

// MARK: - BackupWalletNameViewInput

extension BackupWalletNameViewController: BackupWalletNameViewInput {}

// MARK: - Localizable

extension BackupWalletNameViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - AnimatedTextFieldDelegate

extension BackupWalletNameViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: SoraUI.AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        rootView.nameTextField.backgroundView.set(highlighted: false, animated: false)
        return false
    }

    func animatedTextField(_ textField: SoraUI.AnimatedTextField, shouldChangeCharactersIn _: NSRange, replacementString _: String) -> Bool {
        guard let text = textField.text else {
            return false
        }
        output.nameDidChainged(name: text)
        rootView.continueButton.isEnabled = text.isNotEmpty
        return true
    }
}
