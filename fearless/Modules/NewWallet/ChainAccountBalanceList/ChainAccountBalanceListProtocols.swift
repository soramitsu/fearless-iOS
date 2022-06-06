import SoraFoundation
protocol ChainAccountBalanceListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(state: ChainAccountBalanceListViewState)
    func didReceive(locale: Locale)
}

protocol ChainAccountBalanceListPresenterProtocol: AnyObject {
    func setup()
    func didPullToRefreshOnAssetsTable()
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel)
    func didTapAccountButton()
    func didTapManageAssetsButton()
    func didTapTotalBalanceLabel()
}

protocol ChainAccountBalanceListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func didReceive(currency: Currency)
    func fetchFiats()
}

protocol ChainAccountBalanceListInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAssetIdWithoutPriceId(_ assetId: String)
    func didReceiveSelectedAccount(_ account: MetaAccountModel)
    func didReceiveSupportedCurrencys(_ supportedCurrencys: Result<[Currency], Error>)
    func didRecieveSelectedCurrency(_ selectedCurrency: Currency)
}

protocol ChainAccountBalanceListWireframeProtocol: AlertPresentable, ErrorPresentable, WarningPresentable, AppUpdatePresentable {
    func showChainAccount(
        from view: ChainAccountBalanceListViewProtocol?,
        chain: ChainModel,
        asset: AssetModel
    )
    func showManageAssets(from view: ChainAccountBalanceListViewProtocol?)
    func showWalletSelection(from view: ChainAccountBalanceListViewProtocol?)
    func presentSelectCurrency(
        from view: ControllerBackedProtocol?,
        supportedCurrencys: [Currency],
        selectedCurrency: Currency,
        callback: @escaping ModalPickerSelectionCallback
    )
}
