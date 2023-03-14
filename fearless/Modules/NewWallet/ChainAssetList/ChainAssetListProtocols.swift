import Foundation

typealias ChainAssetListModuleCreationResult = (view: ChainAssetListViewInput, input: ChainAssetListModuleInput)

protocol ChainAssetListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: ChainAssetListViewModel)
    func showEmptyState()
}

protocol ChainAssetListViewOutput: AnyObject {
    func didLoad(view: ChainAssetListViewInput)
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel)
    func didTapAction(actionType: SwipableCellButtonType, viewModel: ChainAccountBalanceCellViewModel)
    func didTapOnIssueButton(viewModel: ChainAccountBalanceCellViewModel)
    func didTapExpandSections(state: HiddenSectionState)
}

protocol ChainAssetListInteractorInput: AnyObject {
    func setup(with output: ChainAssetListInteractorOutput)
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
    func hideChainAsset(_ chainAsset: ChainAsset)
    func showChainAsset(_ chainAsset: ChainAsset)
    func markUnused(chain: ChainModel)
    func saveHiddenSection(state: HiddenSectionState)
}

protocol ChainAssetListInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveWallet(wallet: MetaAccountModel)
    func didReceiveChainsWithIssues(_ issues: [ChainIssue])
    func updateViewModel()
    func didReceive(chainSettings: [ChainSettings])
    func didReceive(accountInfosByChainAssets: [ChainAsset: AccountInfo?])
}

protocol ChainAssetListRouterInput:
    ErrorPresentable,
    WarningPresentable,
    AppUpdatePresentable,
    SheetAlertPresentable,
    PresentDismissable {
    func showChainAccount(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    )
    func showSendFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
    func showReceiveFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        actions: [SheetAlertPresentableAction]
    )
    func showCreate(
        uniqueChainModel: UniqueChainModel,
        from view: ControllerBackedProtocol?
    )
    func showImport(
        uniqueChainModel: UniqueChainModel,
        from view: ControllerBackedProtocol?
    )
}

protocol ChainAssetListModuleInput: AnyObject {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
}

protocol ChainAssetListModuleOutput: AnyObject {}
