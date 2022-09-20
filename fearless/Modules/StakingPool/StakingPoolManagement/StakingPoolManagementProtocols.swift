import Foundation
import SoraFoundation

typealias StakingPoolManagementModuleCreationResult = (view: StakingPoolManagementViewInput, input: StakingPoolManagementModuleInput)

protocol StakingPoolManagementViewInput: ControllerBackedProtocol {
    func didReceive(poolName: String?)
    func didReceive(balanceViewModel: BalanceViewModelProtocol?)
    func didReceive(unstakingViewModel: BalanceViewModelProtocol?)
    func didReceive(stakedAmountString: NSAttributedString)
    func didReceive(redeemDelayViewModel: LocalizableResource<String>?)
    func didReceive(claimableViewModel: BalanceViewModelProtocol?)
    func didReceive(redeemableViewModel: BalanceViewModelProtocol?)
    func didReceive(viewModel: StakingPoolManagementViewModel)
}

protocol StakingPoolManagementViewOutput: AnyObject {
    func didLoad(view: StakingPoolManagementViewInput)
    func didTapCloseButton()
    func didTapStakeMoreButton()
    func didTapUnstakeButton()
    func didTapOptionsButton()
    func didTapClaimButton()
    func didTapRedeemButton()
}

protocol StakingPoolManagementInteractorInput: AnyObject {
    func setup(with output: StakingPoolManagementInteractorOutput)
}

protocol StakingPoolManagementInteractorOutput: AnyObject {
    func didReceive(priceData: PriceData?)
    func didReceive(priceError: Error)
    func didReceive(stakeInfo: StakingPoolMember?)
    func didReceive(stakeInfoError: Error)
    func didReceive(eraStakersInfo: EraStakersInfo)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
    func didReceive(eraStakersInfoError: Error)
    func didReceive(stakingPool: StakingPool?)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceive(error: Error)
    func didReceive(stakingDuration: StakingDuration)
    func didReceive(poolRewards: StakingPoolRewards?)
    func didReceive(poolRewardsError: Error)
}

protocol StakingPoolManagementRouterInput: AnyObject, PresentDismissable {
    func presentStakeMoreFlow(
        flow: StakingBondMoreFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func presentUnbondFlow(
        flow: StakingUnbondSetupFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func presentPoolInfo(
        stakingPool: StakingPool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func presentOptions(
        viewModels: [TitleWithSubtitleViewModel],
        callback: ModalPickerSelectionCallback?,
        from view: ControllerBackedProtocol?
    )

    func presentClaim(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func presentRedeemFlow(
        flow: StakingRedeemConfirmationFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol StakingPoolManagementModuleInput: AnyObject {}

protocol StakingPoolManagementModuleOutput: AnyObject {}
