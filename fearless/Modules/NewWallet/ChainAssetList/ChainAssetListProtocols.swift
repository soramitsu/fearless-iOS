import Foundation
import SSFModels

typealias ChainAssetListModuleCreationResult = (view: ChainAssetListViewInput, input: ChainAssetListModuleInput)

protocol ChainAssetListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: ChainAssetListViewModel)
    func reloadBanners()
}

protocol ChainAssetListViewOutput: AnyObject {
    func didLoad(view: ChainAssetListViewInput)
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel)
    func didTapAction(actionType: SwipableCellButtonType, viewModel: ChainAccountBalanceCellViewModel)
    func didPullToRefresh()
    func didTapManageAsset()
    func didFinishManageAssetAnimate()
    func didTapResolveNetworkIssue(for chain: ChainModel)
    func didTapResolveAccountIssue(for chain: ChainModel)
}

protocol ChainAssetListInteractorInput: AnyObject {
    var shouldRunManageAssetAnimate: Bool { get set }
    func setup(with output: ChainAssetListInteractorOutput)
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor],
        useCashe: Bool
    )
    func markUnused(chain: ChainModel)
    func reload()
    func getAvailableChainAssets(chainAsset: ChainAsset, completion: @escaping (([ChainAsset]) -> Void))
    func hideChainAsset(_ chainAsset: ChainAsset)
    func retryConnection(for chainId: ChainModel.Id)
}

protocol ChainAssetListInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveWallet(wallet: MetaAccountModel)
    func didReceiveChainsWithIssues(_ issues: [ChainIssue])
    func updateViewModel(isInitSearchState: Bool)
    func didReceive(accountInfosByChainAssets: [ChainAsset: AccountInfo?])
    func handleWalletChanged(wallet: MetaAccountModel)
    func didReceive(chainSettings: [ChainSettings])
}

protocol ChainAssetListRouterInput:
    ErrorPresentable,
    WarningPresentable,
    AppUpdatePresentable,
    SheetAlertPresentable,
    PresentDismissable {
    func showAssetNetworks(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    )
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
    func showManageAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        filter: NetworkManagmentFilter?
    )
    func showIssueNotification(
        from view: ControllerBackedProtocol?,
        issues: [ChainIssue],
        wallet: MetaAccountModel
    )
}

protocol ChainAssetListModuleInput: AnyObject {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor],
        networkFilter: NetworkManagmentFilter?
    )
}

protocol ChainAssetListModuleOutput: AnyObject {}
