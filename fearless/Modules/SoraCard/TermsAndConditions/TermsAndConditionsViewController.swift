import UIKit
import SoraFoundation

final class TermsAndConditionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = TermsAndConditionsViewLayout

    // MARK: Private properties

    private let output: TermsAndConditionsViewOutput

    // MARK: - Constructor

    init(
        output: TermsAndConditionsViewOutput,
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
        view = TermsAndConditionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        applyLocalization()
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.generalTermsButton.addTarget(self, action: #selector(termsButtonClicked), for: .touchUpInside)
        rootView.privacyButton.addTarget(self, action: #selector(privacyButtonClicked), for: .touchUpInside)
        rootView.acceptButton.addTarget(self, action: #selector(acceptButtonClicked), for: .touchUpInside)
        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
    }

    @objc private func termsButtonClicked() {
        output.didTapTermsButton()
    }

    @objc private func privacyButtonClicked() {
        output.didTapPrivacyButton()
    }

    @objc private func acceptButtonClicked() {
        output.didTapAcceptButton()
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }
}

// MARK: - TermsAndConditionsViewInput

extension TermsAndConditionsViewController: TermsAndConditionsViewInput {}

// MARK: - Localizable

extension TermsAndConditionsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension TermsAndConditionsViewController: HiddableBarWhenPushed {}
