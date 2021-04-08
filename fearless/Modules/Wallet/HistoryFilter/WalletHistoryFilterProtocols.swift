protocol WalletHistoryFilterViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: WalletHistoryFilterViewModel)
    func didConfirm(viewModel: WalletHistoryFilterViewModel)
}

protocol WalletHistoryFilterPresenterProtocol: AnyObject {
    func setup()
    func toggleFilterItem(at index: Int)
    func apply()
    func reset()
}

protocol WalletHistoryFilterInteractorInputProtocol: AnyObject {}

protocol WalletHistoryFilterInteractorOutputProtocol: AnyObject {}

protocol WalletHistoryFilterWireframeProtocol: AnyObject {}

protocol WalletHistoryFilterViewFactoryProtocol: AnyObject {
    static func createView() -> WalletHistoryFilterViewProtocol?
}
