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

protocol StakingPoolStartInteractorOutput: AnyObject {}

protocol StakingPoolStartRouterInput: AnyObject, PresentDismissable, WebPresentable {
    func presentJoinFlow(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol StakingPoolStartModuleInput: AnyObject {}

protocol StakingPoolStartModuleOutput: AnyObject {}
