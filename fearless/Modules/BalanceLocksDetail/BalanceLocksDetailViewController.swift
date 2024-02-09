import UIKit
import SoraFoundation

final class BalanceLocksDetailViewController: UIViewController, ViewHolder {
    typealias RootViewType = BalanceLocksDetailViewLayout

    // MARK: Private properties

    private let output: BalanceLocksDetailViewOutput

    private var stakingViewModel: BalanceLocksDetailStakingViewModel?
    private var poolViewModel: BalanceLocksDetailPoolViewModel?
    private var liquidityPoolsViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var governanceViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var crowdloanViewModel: LocalizableResource<BalanceViewModelProtocol>?

    // MARK: - Constructor

    init(
        output: BalanceLocksDetailViewOutput,
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
        view = BalanceLocksDetailViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - BalanceLocksDetailViewInput

extension BalanceLocksDetailViewController: BalanceLocksDetailViewInput {
    @MainActor func didReceiveGovernanceLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async {
        governanceViewModel = viewModel

        rootView.governanceView.bindBalance(viewModel: viewModel?.value(for: selectedLocale))
    }

    @MainActor func didReceiveCrowdloanLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async {
        crowdloanViewModel = viewModel

        rootView.crowdloansView.bindBalance(viewModel: viewModel?.value(for: selectedLocale))
    }

    @MainActor func didReceiveStakingLocksViewModel(_ viewModel: BalanceLocksDetailStakingViewModel?) async {
        stakingViewModel = viewModel

        rootView.stakingStakedRowView.bindBalance(viewModel: viewModel?.stakedViewModel?.value(for: selectedLocale))
        rootView.stakingUnstakingRowView.bindBalance(viewModel: viewModel?.unstakingViewModel?.value(for: selectedLocale))
        rootView.stakingRedeemableRowView.bindBalance(viewModel: viewModel?.redeemableViewModel?.value(for: selectedLocale))
    }

    @MainActor func didReceivePoolLocksViewModel(_ viewModel: BalanceLocksDetailPoolViewModel?) async {
        poolViewModel = viewModel

        rootView.poolsStakedRowView.bindBalance(viewModel: viewModel?.stakedViewModel?.value(for: selectedLocale))
        rootView.poolsUnstakingRowView.bindBalance(viewModel: viewModel?.unstakingViewModel?.value(for: selectedLocale))
        rootView.poolsRedeemableRowView.bindBalance(viewModel: viewModel?.redeemableViewModel?.value(for: selectedLocale))
        rootView.poolsClaimableRowView.bindBalance(viewModel: viewModel?.claimableViewModel?.value(for: selectedLocale))
    }

    @MainActor func didReceiveLiquidityPoolLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async {
        liquidityPoolsViewModel = viewModel

        rootView.liquidityPoolsView.bindBalance(viewModel: viewModel?.value(for: selectedLocale))
    }
}

// MARK: - Localizable

extension BalanceLocksDetailViewController: Localizable {
    func applyLocalization() {
        Task {
            await didReceiveGovernanceLocksViewModel(governanceViewModel)
            await didReceiveCrowdloanLocksViewModel(crowdloanViewModel)
            await didReceiveStakingLocksViewModel(stakingViewModel)
            await didReceivePoolLocksViewModel(poolViewModel)
            await didReceiveLiquidityPoolLocksViewModel(liquidityPoolsViewModel)
        }
    }
}
