import CommonWallet

protocol ChooseRecipientViewProtocol: ControllerBackedProtocol {
    func didReceive(tableViewModel: ChooseRecipientTableViewModel)
    func didReceive(viewModel: ChooseRecipientViewModel)
    func didReceive(locale: Locale)
    func didReceive(address: String)
    func didReceive(scamInfo: ScamInfo?, assetName: String)
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
    func setup(with output: ChooseRecipientInteractorOutputProtocol)
    func performSearch(query: String)
    func validate(address: String) -> Bool
}

protocol ChooseRecipientInteractorOutputProtocol: AnyObject {
    func didReceive(searchResult: Result<[SearchData]?, Error>)
    func didReceive(scamInfo: ScamInfo?)
}

protocol ChooseRecipientRouterProtocol: AnyObject {
    func close(_ view: ControllerBackedProtocol?)
    func presentSendAmount(
        from view: ControllerBackedProtocol?,
        to address: String,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        scamInfo: ScamInfo?
    )

    func presentScan(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        moduleOutput: WalletScanQRModuleOutput?
    )

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    )
}
