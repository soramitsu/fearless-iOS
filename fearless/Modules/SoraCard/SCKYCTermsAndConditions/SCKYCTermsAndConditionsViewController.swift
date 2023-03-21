import UIKit
import SoraFoundation

final class SCKYCTermsAndConditionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SCKYCTermsAndConditionsViewLayout

    // MARK: Private properties

    private let output: SCKYCTermsAndConditionsViewOutput

    // MARK: - Constructor

    init(
        output: SCKYCTermsAndConditionsViewOutput,
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
        view = SCKYCTermsAndConditionsViewLayout()
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
        rootView.closeButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
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

// MARK: - SCKYCTermsAndConditionsViewInput

extension SCKYCTermsAndConditionsViewController: SCKYCTermsAndConditionsViewInput {}

// MARK: - Localizable

extension SCKYCTermsAndConditionsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension SCKYCTermsAndConditionsViewController: HiddableBarWhenPushed {}
