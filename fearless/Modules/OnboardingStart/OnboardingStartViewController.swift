import UIKit
import SoraFoundation

protocol OnboardingStartViewOutput: AnyObject {
    func didLoad(view: OnboardingStartViewInput)
    func didTapStartButton()
}

final class OnboardingStartViewController: UIViewController, ViewHolder {
    typealias RootViewType = OnboardingStartViewLayout

    // MARK: Private properties

    private let output: OnboardingStartViewOutput

    // MARK: - Constructor

    init(
        output: OnboardingStartViewOutput,
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
        view = OnboardingStartViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.startButton.addAction { [weak self] in
            self?.output.didTapStartButton()
        }
    }
}

// MARK: - OnboardingStartViewInput

extension OnboardingStartViewController: OnboardingStartViewInput {}

// MARK: - Localizable

extension OnboardingStartViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
