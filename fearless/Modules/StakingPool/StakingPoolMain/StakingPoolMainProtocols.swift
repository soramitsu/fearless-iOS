import Foundation
import SoraFoundation
import BigInt
import SSFModels

typealias StakingPoolMainModuleCreationResult = (view: StakingPoolMainViewInput, input: StakingPoolMainModuleInput)

protocol StakingPoolMainViewInput: ControllerBackedProtocol {
    func didReceiveBalanceViewModel(_ balanceViewModel: BalanceViewModelProtocol)
    func didReceiveChainAsset(_ chainAsset: ChainAsset)
    func didReceiveEstimationViewModel(_ viewModel: StakingEstimationViewModel)
    func didReceiveNetworkInfoViewModels(_ viewModels: [LocalizableResource<NetworkInfoContentViewModel>])
    func didReceiveNominatorStateViewModel(_ viewModel: LocalizableResource<NominationViewModelProtocol>?)
}

protocol StakingPoolMainViewOutput: AnyObject {
    func didLoad(view: StakingPoolMainViewInput)
    func didTapSelectAsset()
    func didTapStartStaking()
    func didTapAccountSelection()
    func performRewardInfoAction()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
    func networkInfoViewDidChangeExpansion(isExpanded: Bool)
    func didTapStakeInfoView()
    func didTapStatusView()
}

protocol StakingPoolMainInteractorInput: AnyObject {
    func setup(with output: StakingPoolMainInteractorOutput)
    func updateWithChainAsset(_ chainAsset: ChainAsset)
    func save(chainAsset: ChainAsset)
    func saveNetworkInfoViewExpansion(isExpanded: Bool)
    func fetchPoolBalance(poolRewardAccountId: AccountId)
    func fetchPoolNomination(poolStashAccountId: AccountId)
}

protocol StakingPoolMainInteractorOutput: AnyObject {
    func didReceive(accountInfo: AccountInfo?)
    func didReceive(chainAsset: ChainAsset)
    func didReceive(rewardCalculatorEngine: RewardCalculatorEngineProtocol?)
    func didReceive(wallet: MetaAccountModel)
    func didReceive(networkInfo: StakingPoolNetworkInfo)
    func didReceive(stakeInfo: StakingPoolMember?)
    func didReceive(era: EraIndex?)
    func didReceive(eraStakersInfo: EraStakersInfo)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
    func didReceive(poolRewards: StakingPoolRewards?)
    func didReceive(stakingPool: StakingPool?)
    func didReceive(palletIdResult: Result<Data, Error>)
    func didReceive(poolAccountInfo: AccountInfo?)
    func didReceive(existentialDepositResult: Result<BigUInt, Error>)
    func didReceive(nomination: Nomination?)
    func didReceiveError(_ error: StakingPoolMainError)
    func didReceive(pendingRewards: BigUInt?)
    func didReceive(pendingRewardsError: Error)
}

protocol StakingPoolMainRouterInput: AnyObject, AccountManagementPresentable {
    func showChainAssetSelection(
        from view: StakingPoolMainViewInput?,
        type: AssetSelectionStakingType,
        delegate: AssetSelectionDelegate
    )

    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        maxReward: (title: String, amount: Decimal),
        avgReward: (title: String, amount: Decimal)
    )

    func showSetupAmount(
        from view: ControllerBackedProtocol?,
        amount: Decimal?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showAccountsSelection(
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput
    )

    func showStakingManagement(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        status: NominationViewStatus?,
        from view: ControllerBackedProtocol?
    ) -> StakingPoolManagementModuleInput?

    func showPoolValidators(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol StakingPoolMainModuleInput: AnyObject {}

protocol StakingPoolMainModuleOutput: AnyObject {}
