import UIKit
import SoraFoundation
import SoraUI

protocol BackupWalletNameViewOutput: AnyObject {
    func didLoad(view: BackupWalletNameViewInput)
    func didBackButtonTapped()
    func didContinueButtonTapped()
}

final class BackupWalletNameViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupWalletNameViewLayout

    // MARK: Private properties

    private let output: BackupWalletNameViewOutput

    private let mode: WalletNameScreenMode
    private var nameInputViewModel: InputViewModelProtocol?

    // MARK: - Constructor

    init(
        mode: WalletNameScreenMode,
        output: BackupWalletNameViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = BackupWalletNameViewLayout(mode: mode)
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
        rootView.nameTextField.animatedInputField.addTarget(
            self,
            action: #selector(actionInputChange),
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
    }

    @objc private func actionInputChange() {
        if nameInputViewModel?.inputHandler.value != rootView.nameTextField.text {
            rootView.nameTextField.text = nameInputViewModel?.inputHandler.value
        }

        let enabled = nameInputViewModel?.inputHandler.completed ?? false
        rootView.continueButton.set(enabled: enabled)
    }
}

// MARK: - BackupWalletNameViewInput

extension BackupWalletNameViewController: BackupWalletNameViewInput {
    func setInputViewModel(_ viewModel: InputViewModelProtocol) {
        nameInputViewModel = viewModel
        rootView.nameTextField.animatedInputField.text = viewModel.inputHandler.value
    }
}

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

    func animatedTextField(
        _ textField: SoraUI.AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let currentViewModel = nameInputViewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }
}
