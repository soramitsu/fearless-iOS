import UIKit
import SoraFoundation

final class IntroduceViewController: UIViewController, ViewHolder {
    typealias RootViewType = IntroduceViewLayout

    // MARK: Private properties

    private let output: IntroduceViewOutput
    private var enteredName: String = ""
    private var enteredLastName: String = ""

    // MARK: - Constructor

    init(
        output: IntroduceViewOutput,
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
        view = IntroduceViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        applyLocalization()
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.continueButton.addTarget(self, action: #selector(continueButtonClicked), for: .touchUpInside)
        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.closeButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        rootView.nameInputField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.enteredName = self?.rootView.nameInputField.sora.text ?? ""
            self?.updateContinueButton()
        }
        rootView.lastNameInputField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.enteredLastName = self?.rootView.lastNameInputField.sora.text ?? ""
            self?.updateContinueButton()
        }
    }

    private func updateContinueButton() {
        if !(enteredName.isEmpty || enteredLastName.isEmpty) {
            rootView.continueButton.applySoraSecondaryStyle()
        } else {
            rootView.continueButton.applyDisabledStyle()
        }
    }

    @objc private func continueButtonClicked() {
        output.didTapContinueButton(name: enteredName, lastName: enteredLastName)
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }
}

// MARK: - IntroduceViewInput

extension IntroduceViewController: IntroduceViewInput {}

// MARK: - Localizable

extension IntroduceViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension IntroduceViewController: HiddableBarWhenPushed {}
