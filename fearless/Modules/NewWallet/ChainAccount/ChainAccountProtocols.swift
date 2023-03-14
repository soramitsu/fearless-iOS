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
    func didTapSelectNetwork()
    func addressDidCopied()
    func didTapPolkaswapButton()
}

protocol ChainAccountInteractorInputProtocol: AnyObject {
    func setup()
    func getAvailableExportOptions(for address: String)
    func update(chain: ChainModel)

    var chainAsset: ChainAsset { get }
    var availableChainAssets: [ChainAsset] { get }
}

protocol ChainAccountInteractorOutputProtocol: AnyObject {
    func didReceiveExportOptions(options: [ExportOption])
    func didUpdate(chainAsset: ChainAsset)
}

protocol ChainAccountWireframeProtocol: ErrorPresentable,
    SheetAlertPresentable,
    ModalAlertPresenting,
    AuthorizationPresentable,
    ApplicationStatusPresentable {
    func close(view: ControllerBackedProtocol?)

    func presentSendFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func presentReceiveFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        wallet: MetaAccountModel
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
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func showUniqueChainSourceSelection(
        from view: ControllerBackedProtocol?,
        items: [ReplaceChainOption],
        callback: @escaping ModalPickerSelectionCallback
    )

    func showCreate(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?)
    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?)

    func showSelectNetwork(
        from view: ChainAccountViewProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )
    func showPolkaswap(
        from view: ChainAccountViewProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol ChainAccountModuleInput: AnyObject {}

protocol ChainAccountModuleOutput: AnyObject {
    func updateTransactionHistory(for chainAsset: ChainAsset?)
}
