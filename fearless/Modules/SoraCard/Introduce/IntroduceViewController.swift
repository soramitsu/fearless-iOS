import UIKit
import SoraFoundation

final class IntroduceViewController: UIViewController, ViewHolder {
    typealias RootViewType = IntroduceViewLayout

    // MARK: Private properties

    private let output: IntroduceViewOutput

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
    }

    @objc private func continueButtonClicked() {
        guard let name = rootView.nameInputField.textField.text,
              let lastName = rootView.lastNameInputField.textField.text,
              !name.isEmpty, !lastName.isEmpty else { return }
        output.didTapContinueButton(name: name, lastName: lastName)
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
