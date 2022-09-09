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
    func didReceive(poolName: String?)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceive(error: Error)
    func didReceive(stakingDuration: StakingDuration)
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
}

protocol StakingPoolManagementModuleInput: AnyObject {}

protocol StakingPoolManagementModuleOutput: AnyObject {}
