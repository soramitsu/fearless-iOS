import Foundation
import SoraFoundation

protocol StakingAmountViewProtocol: ControllerBackedProtocol {
    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>)
}

protocol StakingAmountPresenterProtocol: class {
    func setup()
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectAmountPercentage(_ percentage: Float)
    func selectPayoutAccount()
    func close()
}

protocol StakingAmountInteractorInputProtocol: class {
    func fetchAccounts()
}

protocol StakingAmountInteractorOutputProtocol: class {
    func didReceive(accounts: [ManagedAccountItem])
    func didReceive(error: Error)
}

protocol StakingAmountWireframeProtocol: class {
    func close(view: StakingAmountViewProtocol?)
}

protocol StakingAmountViewFactoryProtocol: class {
	static func createView() -> StakingAmountViewProtocol?
}
