import Foundation

typealias StakingPoolInfoModuleCreationResult = (view: StakingPoolInfoViewInput, input: StakingPoolInfoModuleInput)

protocol StakingPoolInfoViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: StakingPoolInfoViewModel)
}

protocol StakingPoolInfoViewOutput: AnyObject {
    func didLoad(view: StakingPoolInfoViewInput)
    func didTapCloseButton()
    func didTapValidators()
}

protocol StakingPoolInfoInteractorInput: AnyObject {
    func setup(with output: StakingPoolInfoInteractorOutput)
}

protocol StakingPoolInfoInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>)
    func didReceive(palletIdResult: Result<Data, Error>)
}

protocol StakingPoolInfoRouterInput: PresentDismissable {
    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        poolId: UInt32,
        state: ExistingBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol StakingPoolInfoModuleInput: AnyObject {}

protocol StakingPoolInfoModuleOutput: AnyObject {}
