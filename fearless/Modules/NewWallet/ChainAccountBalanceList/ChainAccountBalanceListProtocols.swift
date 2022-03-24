import SoraFoundation
protocol ChainAccountBalanceListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(state: ChainAccountBalanceListViewState)
}

protocol ChainAccountBalanceListPresenterProtocol: AnyObject {
    func setup()
    func didPullToRefreshOnAssetsTable()
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel)
    func didTapAccountButton()
    func didTapManageAssetsButton()
}

protocol ChainAccountBalanceListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol ChainAccountBalanceListInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId)
    func didReceiveSelectedAccount(_ account: MetaAccountModel)
}

protocol ChainAccountBalanceListWireframeProtocol: AlertPresentable, ErrorPresentable, WarningPresentable, AppUpdatePresentable {
    func showChainAccount(
        from view: ChainAccountBalanceListViewProtocol?,
        chain: ChainModel,
        asset: AssetModel
    )

    func showManageAssets(from view: ChainAccountBalanceListViewProtocol?)

    func showWalletSelection(from view: ChainAccountBalanceListViewProtocol?)
}
