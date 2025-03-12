import UIKit
import SoraFoundation

protocol CrossChainFundsPermissionViewOutput: AnyObject {
    func didLoad(view: CrossChainFundsPermissionViewInput)
    func didTapConfirmButton()
    func didTapBackButton()
}

final class CrossChainFundsPermissionViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = CrossChainFundsPermissionViewLayout

    // MARK: Private properties
    private let output: CrossChainFundsPermissionViewOutput

    // MARK: - Constructor
    init(
        output: CrossChainFundsPermissionViewOutput,
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
        view = CrossChainFundsPermissionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }
    
    // MARK: - Private methods
    
    private func setupActions() {
        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.confirmButton.addTarget(self, action: #selector(continueButtonClicked), for: .touchUpInside)
    }

    @objc private func continueButtonClicked() {
        output.didTapConfirmButton()
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }
}

// MARK: - CrossChainFundsPermissionViewInput
extension CrossChainFundsPermissionViewController: CrossChainFundsPermissionViewInput {
    func setButtonLoadingState(isLoading: Bool) {
        rootView.confirmButton.set(loading: isLoading)
    }
    
    func bind(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }
    
    func didReceiveContinueButton(isReady: Bool) {
        rootView.confirmButton.set(enabled: isReady)
    }

    func bind(viewModel: CrossChainFundsPermissionViewModel) {
        rootView.bind(viewModel: viewModel)
    }
    
    func didReceiveError(viewModel: ErrorViewModel?) {
        rootView.bind(errorViewModel: viewModel)
    }
}

// MARK: - Localizable
extension CrossChainFundsPermissionViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
