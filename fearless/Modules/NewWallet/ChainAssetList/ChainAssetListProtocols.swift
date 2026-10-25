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
    func didSelectLens(_ lens: PortfolioLens, walletId: String)
    func didTapTokenAction(actionType: SwipableCellButtonType, groupId: String, walletId: String)
    func didTapFunding(_ action: PortfolioFundingAction, walletId: String)
    func didPullToRefresh()
    func didTapManageAsset()
    /// "N hidden assets not included · Manage" under the list.
    func didTapHiddenAssetsNotIncluded()
    /// "N testnet assets not included · Manage" under the list.
    func didTapTestnetAssetsNotIncluded()
    /// The "N hidden assets hold funds" notice.
    func didTapReviewHiddenFunds()
    func didTapKeepHiddenFunds(assetKeys: [AssetKey])
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
    func showChainAsset(_ chainAsset: ChainAsset)
    func retryConnection(for chainId: ChainModel.Id)
    func adoptStoredWalletSeed()
}

extension ChainAssetListInteractorInput {
    func showChainAsset(_: ChainAsset) {}
}

protocol ChainAssetListInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveWallet(wallet: MetaAccountModel)
    func didReceiveChainsWithIssues(_ issues: [ChainIssue])
    func updateViewModel(isInitSearchState: Bool)
    func didReceive(accountInfosByChainAssets: [ChainAsset: AccountInfo?])
    func handleWalletChanged(wallet: MetaAccountModel)
    func didReceive(chainSettings: [ChainSettings])
    func didAdoptStoredWalletSeed(result: Result<MetaAccountModel, Error>)
}

protocol ChainAssetListRouterInput:
    ErrorPresentable,
    WarningPresentable,
    AppUpdatePresentable,
    SheetAlertPresentable,
    PresentDismissable {
    func showFundingOptions(from view: ControllerBackedProtocol?, title: String, options: [PortfolioFundingOption], locale: Locale)
    func showGroupHideConfirmation(from view: ControllerBackedProtocol?, viewModel: SheetAlertPresentableViewModel)
    func showPurchase(from view: ControllerBackedProtocol?, action: PurchaseAction)
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
        filter: NetworkManagmentFilter?,
        visibilityFilter: ManageAssetsFilter
    )
    func showIssueNotification(
        from view: ControllerBackedProtocol?,
        issues: [ChainIssue],
        wallet: MetaAccountModel
    )
    /// The wallet list, where another wallet is created, restored or selected.
    func showWalletManagment(from view: ControllerBackedProtocol?)
}

protocol ChainAssetListModuleInput: AnyObject {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor],
        networkFilter: NetworkManagmentFilter?
    )
}

protocol ChainAssetListModuleOutput: AnyObject {}

extension ChainAssetListViewOutput {
    func didTapFunding(_: PortfolioFundingAction, walletId _: String) {}
}

extension ChainAssetListRouterInput {
    func showFundingOptions(from _: ControllerBackedProtocol?, title _: String, options _: [PortfolioFundingOption], locale _: Locale) {}
    func showGroupHideConfirmation(from _: ControllerBackedProtocol?, viewModel _: SheetAlertPresentableViewModel) {}
    func showPurchase(from _: ControllerBackedProtocol?, action _: PurchaseAction) {}
}
