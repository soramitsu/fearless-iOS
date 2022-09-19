import UIKit
import SoraFoundation

final class StakingPoolManagementViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingPoolManagementViewLayout

    // MARK: Private properties

    private let output: StakingPoolManagementViewOutput

    // MARK: - Constructor

    init(
        output: StakingPoolManagementViewOutput,
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
        view = StakingPoolManagementViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        rootView.stakeMoreButton.addTarget(
            self,
            action: #selector(stakeMoreButtonClicked),
            for: .touchUpInside
        )

        rootView.unstakeButton.addTarget(
            self,
            action: #selector(unstakeButtonClicked),
            for: .touchUpInside
        )

        rootView.optionsButton.addTarget(
            self,
            action: #selector(optionsButtonClicked),
            for: .touchUpInside
        )

        rootView.claimView.actionButton?.addTarget(
            self,
            action: #selector(claimButtonClicked),
            for: .touchUpInside
        )
    }

    // MARK: - Private methods

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }

    @objc private func stakeMoreButtonClicked() {
        output.didTapStakeMoreButton()
    }

    @objc private func unstakeButtonClicked() {
        output.didTapUnstakeButton()
    }

    @objc private func optionsButtonClicked() {
        output.didTapOptionsButton()
    }

    @objc private func claimButtonClicked() {
        output.didTapClaimButton()
    }

    @objc private func redeemButtonClicked() {
        output.didTapRedeemButton()
    }
}

// MARK: - StakingPoolManagementViewInput

extension StakingPoolManagementViewController: StakingPoolManagementViewInput {
    func didReceive(poolName: String?) {
        rootView.bind(poolName: poolName)
    }

    func didReceive(balanceViewModel: BalanceViewModelProtocol?) {
        rootView.bind(balanceViewModel: balanceViewModel)
    }

    func didReceive(unstakingViewModel: BalanceViewModelProtocol?) {
        rootView.bind(unstakeBalanceViewModel: unstakingViewModel)
    }

    func didReceive(stakedAmountString: NSAttributedString) {
        rootView.bind(stakedAmountString: stakedAmountString)
    }

    func didReceive(redeemDelayViewModel: LocalizableResource<String>?) {
        rootView.bind(redeemDelayViewModel: redeemDelayViewModel)
    }

    func didReceive(claimableViewModel: BalanceViewModelProtocol?) {
        rootView.bind(claimableViewModel: claimableViewModel)
    }

    func didReceive(redeemableViewModel: BalanceViewModelProtocol?) {
        rootView.bind(redeemableViewModel: redeemableViewModel)
    }

    func didReceive(viewModel: StakingPoolManagementViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension StakingPoolManagementViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
