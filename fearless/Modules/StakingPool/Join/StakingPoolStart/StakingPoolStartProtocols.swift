import Foundation
typealias StakingPoolStartModuleCreationResult = (view: StakingPoolStartViewInput, input: StakingPoolStartModuleInput)

protocol StakingPoolStartViewInput: ControllerBackedProtocol {
    func didReceive(locale: Locale)
    func didReceive(viewModel: StakingPoolStartViewModel)
}

protocol StakingPoolStartViewOutput: AnyObject {
    func didLoad(view: StakingPoolStartViewInput)
    func didTapBackButton()
    func didTapJoinPoolButton()
    func didTapCreatePoolButton()
    func didTapWatchAboutButton()
}

protocol StakingPoolStartInteractorInput: AnyObject {
    func setup(with output: StakingPoolStartInteractorOutput)
}

protocol StakingPoolStartInteractorOutput: AnyObject {
    func didReceive(stakingDuration: StakingDuration)
    func didReceive(error: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
}

protocol StakingPoolStartRouterInput: AnyObject, PresentDismissable, WebPresentable {
    func presentJoinFlow(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        amount: Decimal?,
        from view: ControllerBackedProtocol?
    )
}

protocol StakingPoolStartModuleInput: AnyObject {}

protocol StakingPoolStartModuleOutput: AnyObject {}
