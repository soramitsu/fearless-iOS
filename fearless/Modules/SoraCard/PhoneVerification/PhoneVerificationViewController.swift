import UIKit
import SoraFoundation

final class PhoneVerificationViewController: UIViewController, ViewHolder {
    typealias RootViewType = PhoneVerificationViewLayout

    // MARK: Private properties

    private let output: PhoneVerificationViewOutput

    // MARK: - Constructor

    init(
        output: PhoneVerificationViewOutput,
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
        view = PhoneVerificationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        applyLocalization()
        configure()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        rootView.resetTextFieldState()
    }

    func set(state: PhoneVerificationState) {
        rootView.set(state: state)
    }

    // MARK: - Private methods

    private func configure() {
        rootView.sendButton.addTarget(self, action: #selector(sendButtonClicked), for: .touchUpInside)
        rootView.phoneInputField.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.set(state: (self?.rootView.phoneInputField.textField.text?.isEmpty ?? true) ? .disabled(errorMessage: "Empty") : .enabled)
        }
        rootView.phoneInputField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.rootView.resetTextFieldState()
        }
        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.closeButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
    }

    @objc private func sendButtonClicked() {
        guard let phone = rootView.phoneInputField.textField.text, !phone.isEmpty else { return }
        rootView.set(state: .inProgress)
        output.didTapSendButton(with: phone)
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }
}

// MARK: - PhoneVerificationViewInput

extension PhoneVerificationViewController: PhoneVerificationViewInput {
    func didReceive(error: String) {
        set(state: .disabled(errorMessage: error))
    }
}

// MARK: - Localizable

extension PhoneVerificationViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension PhoneVerificationViewController: HiddableBarWhenPushed {}
