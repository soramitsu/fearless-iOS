import CommonWallet

protocol ChooseRecipientViewProtocol: ControllerBackedProtocol {
    func didReceive(tableViewModel: ChooseRecipientTableViewModel)
    func didReceive(viewModel: ChooseRecipientViewModel)
    func didReceive(locale: Locale)
    func didReceive(address: String)
}

protocol ChooseRecipientPresenterProtocol: AnyObject {
    func setup()
    func searchTextDidChanged(_ text: String)
    func didTapBackButton()
    func didSelectViewModel(cellViewModel: SearchPeopleTableCellViewModel)
    func didTapScanButton()
    func didTapHistoryButton()
    func didTapPasteButton()
    func didTapNextButton(with address: String)
}

protocol ChooseRecipientInteractorInputProtocol: AnyObject {
    func performSearch(query: String)
    func validate(address: String) -> Bool
}

protocol ChooseRecipientInteractorOutputProtocol: AnyObject {
    func didReceive(searchResult: Result<[SearchData]?, Error>)
}

protocol ChooseRecipientRouterProtocol: AnyObject {
    func close(_ view: ControllerBackedProtocol?)
    func presentSendAmount(
        from view: ControllerBackedProtocol?,
        to address: String,
        asset: AssetModel,
        chain: ChainModel,
        wallet: MetaAccountModel
    )

    func presentScan(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        moduleOutput: WalletScanQRModuleOutput?
    )

    func presentHistory(
        from view: ControllerBackedProtocol?
    )
}
