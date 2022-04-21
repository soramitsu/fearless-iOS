import BigInt

protocol ChainAccountViewProtocol: ControllerBackedProtocol, Containable {
    func didReceiveState(_ state: ChainAccountViewState)
}

protocol ChainAccountPresenterProtocol: AnyObject {
    func setup()
    func didTapBackButton()

    func didTapSendButton()
    func didTapReceiveButton()
    func didTapBuyButton()
    func didTapOptionsButton()
    func didTapInfoButton()
}

protocol ChainAccountInteractorInputProtocol: AnyObject {
    func setup()
    func getAvailableExportOptions(for address: String)

    var chain: ChainModel { get set }
}

protocol ChainAccountInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceiveBalanceLocks(result: Result<BalanceLocks?, Error>)
    func didReceiveExportOptions(options: [ExportOption])
}

protocol ChainAccountWireframeProtocol: ErrorPresentable,
    AlertPresentable,
    ModalAlertPresenting,
    AuthorizationPresentable {
    func close(view: ControllerBackedProtocol?)

    func presentSendFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        transferFinishBlock: WalletTransferFinishBlock?
    )

    func presentReceiveFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel
    )

    func presentBuyFlow(
        from view: ControllerBackedProtocol?,
        items: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    )

    func presentPurchaseWebView(
        from view: ControllerBackedProtocol?,
        action: PurchaseAction
    )

    func presentLockedInfo(
        from view: ControllerBackedProtocol?,
        balanceContext: BalanceContext,
        info: AssetBalanceDisplayInfo
    )

    func presentChainActionsFlow(
        from view: ControllerBackedProtocol?,
        items: [ChainAction],
        chain: ChainModel,
        callback: @escaping ModalPickerSelectionCallback
    )

    func presentNodeSelection(
        from view: ControllerBackedProtocol?,
        chain: ChainModel
    )

    func showExport(
        for address: String,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    )

    func showUniqueChainSourceSelection(
        from view: ControllerBackedProtocol?,
        items: [ReplaceChainOption],
        callback: @escaping ModalPickerSelectionCallback
    )

    func showCreate(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?)
    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?)
}

protocol ChainAccountModuleInput: AnyObject {}

protocol ChainAccountModuleOutput: AnyObject {
    func updateTransactionHistory()
}
