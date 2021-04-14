import SoraFoundation

protocol StakingRewardPayoutsViewProtocol: ControllerBackedProtocol, Localizable {
    func startLoading()
    func stopLoading()
    func showEmptyView()
    func hideEmptyView()
    func reloadTable(with cellViewModels: [StakingRewardHistoryCellViewModel])
}

protocol StakingRewardPayoutsPresenterProtocol: AnyObject {
    func setup()
    func handleSelectedHistory(at indexPath: IndexPath)
    func handlePayoutAction()
}

protocol StakingRewardPayoutsInteractorInputProtocol: AnyObject {}

protocol StakingRewardPayoutsInteractorOutputProtocol: AnyObject {}

protocol StakingRewardPayoutsWireframeProtocol: AnyObject {
    func showRewardDetails(from view: ControllerBackedProtocol?)
}

protocol StakingRewardPayoutsViewFactoryProtocol: AnyObject {
    static func createView() -> StakingRewardPayoutsViewProtocol?
}
