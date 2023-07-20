import UIKit
import SoraFoundation
import SoraUI

protocol WalletNameViewOutput: AnyObject {
    func didLoad(view: WalletNameViewInput)
    func didBackButtonTapped()
    func didContinueButtonTapped()
}

final class WalletNameViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletNameViewLayout

    // MARK: Private properties

    private let output: WalletNameViewOutput

    private let mode: WalletNameScreenMode
    private var nameInputViewModel: InputViewModelProtocol?

    // MARK: - Constructor

    init(
        mode: WalletNameScreenMode,
        output: WalletNameViewOutput,
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
        view = WalletNameViewLayout(mode: mode)
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

extension WalletNameViewController: WalletNameViewInput {
    func setInputViewModel(_ viewModel: InputViewModelProtocol) {
        nameInputViewModel = viewModel
        rootView.nameTextField.animatedInputField.text = viewModel.inputHandler.value
    }
}

// MARK: - Localizable

extension WalletNameViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - AnimatedTextFieldDelegate

extension WalletNameViewController: AnimatedTextFieldDelegate {
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
