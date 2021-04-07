protocol WalletHistoryFilterViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: WalletHistoryFilterViewModel)
}

protocol WalletHistoryFilterPresenterProtocol: AnyObject {
    func setup()
    func toggleTransfers()
    func toggleRewardsAndSlashes()
    func toggleExtrinisics()
    func apply()
    func reset()
}

protocol WalletHistoryFilterInteractorInputProtocol: AnyObject {}

protocol WalletHistoryFilterInteractorOutputProtocol: AnyObject {}

protocol WalletHistoryFilterWireframeProtocol: AnyObject {}

protocol WalletHistoryFilterViewFactoryProtocol: AnyObject {
    static func createView() -> WalletHistoryFilterViewProtocol?
}
