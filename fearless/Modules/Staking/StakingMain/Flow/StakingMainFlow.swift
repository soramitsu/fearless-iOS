enum StakingMainFlow {
    case parachain
    case relaychain
}

protocol StakingMainModelStateListener: AnyObject {
    func provideStakingMainModel()
    func provideStakingInfoModel()
    func didReceive(error: Error)
}

protocol StakingMainViewModelState {
    var stateListener: StakingMainModelStateListener { get set }

    func setStateListener(_ stateListener: StakingMainModelStateListener?)
}

struct StakingMainDependencyContainer {
    let viewModelState: StakingMainViewModelState
    let strategy: StakingMainStrategy
    let viewModelFactory: StakingMainViewModelFactoryProtocol
}

protocol StakingMainViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingMainViewModelState
    ) -> StakingMainViewModel
}

protocol StakingMainStrategy {
    func setup()
}
