import Foundation

protocol StakingMainModelStateListener: AnyObject {
    func provideStakingMainModel()
    func provideStakingInfoModel()
    func didReceive(error: Error)
}

protocol StakingMainViewModelState {
    var stateListener: StakingMainModelStateListener { get set }

    func setStateListener(_ stateListener: StakingMainModelStateListener?)
}

protocol StakingMainViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingMainViewModelState
    ) -> StakingMainViewModel
}

protocol StakingMainStrategy {
    func setup()
}
