import Foundation

typealias StakingPoolInfoModuleCreationResult = (view: StakingPoolInfoViewInput, input: StakingPoolInfoModuleInput)

protocol StakingPoolInfoViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: StakingPoolInfoViewModel)
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
}

protocol StakingPoolInfoInteractorInput: AnyObject {
    func setup(with output: StakingPoolInfoInteractorOutput)
}

protocol StakingPoolInfoInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>)
    func didReceive(palletIdResult: Result<Data, Error>)
    func didReceive(stakingPool: StakingPool?)
}

protocol StakingPoolInfoRouterInput: PresentDismissable {
    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        poolId: UInt32,
        state: ExistingBonding,
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

protocol StakingPoolInfoModuleInput: AnyObject {}

protocol StakingPoolInfoModuleOutput: AnyObject {}
