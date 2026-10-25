import UIKit
import SoraFoundation

protocol OnboardingStartViewOutput: AnyObject {
    func didLoad(view: OnboardingStartViewInput)
    func didTapStartButton()
}

final class OnboardingStartViewController: UIViewController {
    // MARK: Private properties

    private let output: OnboardingStartViewOutput
    private let welcomeAppearanceEnabled: Bool
    private(set) var welcomeView: FWWelcomeView?

    // MARK: - Constructor

    init(
        output: OnboardingStartViewOutput,
        localizationManager: LocalizationManagerProtocol?,
        welcomeAppearanceEnabled: Bool = FWAppearance.welcomeRestyled
    ) {
        self.output = output
        self.welcomeAppearanceEnabled = welcomeAppearanceEnabled
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        if welcomeAppearanceEnabled {
            let welcome = FWWelcomeView(mode: .introduction)
            welcomeView = welcome
            view = welcome
        } else {
            view = OnboardingStartViewLayout()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyLocalization()
        output.didLoad(view: self)
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        let button: UIControl?
        if let welcomeView {
            button = welcomeView.primaryButton
        } else {
            button = (view as? OnboardingStartViewLayout)?.startButton
        }
        button?.addAction { [weak self] in
            self?.output.didTapStartButton()
        }
    }
}

// MARK: - OnboardingStartViewInput

extension OnboardingStartViewController: OnboardingStartViewInput {}

// MARK: - Localizable

extension OnboardingStartViewController: Localizable {
    func applyLocalization() {
        // SoraFoundation calls this when the manager is assigned, before loadView.
        guard isViewLoaded else { return }
        if let welcomeView {
            welcomeView.locale = selectedLocale
        } else {
            (view as? OnboardingStartViewLayout)?.locale = selectedLocale
        }
    }
}
