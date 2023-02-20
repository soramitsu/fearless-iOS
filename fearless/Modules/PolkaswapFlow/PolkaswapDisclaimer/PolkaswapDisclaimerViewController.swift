import UIKit
import SoraFoundation

protocol PolkaswapDisclaimerViewOutput: AnyObject {
    func didLoad(view: PolkaswapDisclaimerViewInput)
    func didContinueButtonTapped()
    func didBackButtonTapped()
}

final class PolkaswapDisclaimerViewController: UIViewController, ViewHolder {
    typealias RootViewType = PolkaswapDisclaimerViewLayout

    // MARK: Private properties

    private let output: PolkaswapDisclaimerViewOutput

    // MARK: - Constructor

    init(
        output: PolkaswapDisclaimerViewOutput,
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
        view = PolkaswapDisclaimerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.confirmSwitch.addAction { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.rootView.continueButton.isEnabled = strongSelf.rootView.confirmSwitch.isOn
        }
        rootView.continueButton.addAction { [weak self] in
            self?.output.didContinueButtonTapped()
        }
        rootView.navigationBar.backButton.addAction {
            self.output.didBackButtonTapped()
        }
    }
}

// MARK: - PolkaswapDisclaimerViewInput

extension PolkaswapDisclaimerViewController: PolkaswapDisclaimerViewInput {
    func didReceive(viewModel: PolkaswapDisclaimerViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceiveDisclaimer(isRead: Bool) {
        rootView.confirmSwitch.isUserInteractionEnabled = !isRead
        rootView.continueButton.isEnabled = isRead
    }
}

// MARK: - Localizable

extension PolkaswapDisclaimerViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
