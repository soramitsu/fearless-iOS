import Foundation

typealias StakingPoolInfoModuleCreationResult = (view: StakingPoolInfoViewInput, input: StakingPoolInfoModuleInput)

protocol StakingPoolInfoViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: StakingPoolInfoViewModel)
    func didReceive(status: NominationViewStatus?)
}

protocol StakingPoolInfoViewOutput: AnyObject {
    func didLoad(view: StakingPoolInfoViewInput)
    func didTapCloseButton()
    func didTapValidators()
    func willAppear(view: StakingPoolInfoViewInput)
    func nominatorDidTapped()
    func stateTogglerDidTapped()
    func rootDidTapped()
    func saveRolesDidTapped()
    func copyAddressTapped()
}

protocol StakingPoolInfoInteractorInput: AnyObject {
    func setup(with output: StakingPoolInfoInteractorOutput)
    func fetchPoolNomination(poolStashAccountId: AccountId, activeEra: EraIndex)
}

protocol StakingPoolInfoInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveValidators(validators: YourValidatorsModel)
    func didReceive(palletIdResult: Result<Data, Error>)
    func didReceive(stakingPool: StakingPool?)
    func didReceive(error: Error)
    func didReceive(activeEra: Result<ActiveEraInfo?, Error>)
}

protocol StakingPoolInfoRouterInput: PresentDismissable, ApplicationStatusPresentable {
    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showWalletManagment(
        contextTag: Int,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    )

    func showUpdateRoles(
        roles: StakingPoolRoles,
        poolId: String,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol StakingPoolInfoModuleInput: AnyObject {
    func didChange(status: NominationViewStatus)
}

protocol StakingPoolInfoModuleOutput: AnyObject {}
