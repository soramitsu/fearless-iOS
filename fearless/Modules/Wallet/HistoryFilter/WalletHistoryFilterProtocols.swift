import CommonWallet

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

protocol WalletHistoryFilterWireframeProtocol: AnyObject {
    func proceed(from view: WalletHistoryFilterViewProtocol?, applying filter: WalletHistoryFilter)
}

protocol WalletHistoryFilterViewFactoryProtocol: AnyObject {
    static func createView(
        request: WalletHistoryRequest,
        commandFactory: WalletCommandFactoryProtocol,
        delegate: HistoryFilterEditingDelegate?
    ) -> WalletHistoryFilterViewProtocol?
}
