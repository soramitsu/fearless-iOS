typealias ChainAssetListModuleCreationResult = (view: ChainAssetListViewInput, input: ChainAssetListModuleInput)

protocol ChainAssetListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: ChainAssetListViewModel)
    func showEmptyState()
    func runtimesBuilded(count: Int)
}

protocol ChainAssetListViewOutput: AnyObject {
    func didLoad(view: ChainAssetListViewInput)
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel)
    func didTapAction(actionType: SwipableCellButtonType, viewModel: ChainAccountBalanceCellViewModel)
    func didTapOnIssueButton(viewModel: ChainAccountBalanceCellViewModel)
}

protocol ChainAssetListInteractorInput: AnyObject {
    func setup(with output: ChainAssetListInteractorOutput)
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
    func hideChainAsset(_ chainAsset: ChainAsset)
    func showChainAsset(_ chainAsset: ChainAsset)
}

protocol ChainAssetListInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveWallet(wallet: MetaAccountModel)
    func didReceiveChainsWithIssues(_ issues: [ChainIssue])
    func updateViewModel()
    func snapshotWasBuilded(count: Int)
}

protocol ChainAssetListRouterInput: AlertPresentable, ErrorPresentable, WarningPresentable, AppUpdatePresentable, SheetAlertPresentable {
    func showChainAccount(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    )
    func showSendFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        transferFinishBlock: WalletTransferFinishBlock?
    )
    func showReceiveFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol ChainAssetListModuleInput: AnyObject {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
}

protocol ChainAssetListModuleOutput: AnyObject {}
