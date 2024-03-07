import BigInt
import Foundation
import SSFModels

protocol ChainAccountViewProtocol: ControllerBackedProtocol, Containable {
    func didReceiveState(_ state: ChainAccountViewState)
    func didReceive(balanceViewModel: ChainAccountBalanceViewModel?)
}

protocol ChainAccountPresenterProtocol: AnyObject {
    func setup()
    func didTapBackButton()

    func didTapSendButton()
    func didTapReceiveButton()
    func didTapBuyButton()
    func didTapOptionsButton()
    func didTapCrossChainButton()
    func didTapSelectNetwork()
    func addressDidCopied()
    func didTapPolkaswapButton()
    func didTapLockedInfoButton()
    func didPullToRefresh()
}

protocol ChainAccountInteractorInputProtocol: AnyObject {
    func setup()
    func getAvailableExportOptions(for address: String)
    func update(chain: ChainModel)
    func updateData()
    func checkIsClaimAvailable() -> Bool

    var chainAsset: ChainAsset { get }
    var availableChainAssets: [ChainAsset] { get }
}

protocol ChainAccountInteractorOutputProtocol: AnyObject {
    func didReceiveExportOptions(options: [ExportOption])
    func didUpdate(chainAsset: ChainAsset)
    func didReceiveBalanceLocks(_ balanceLocks: Decimal?)
    func didReceiveBalanceLocksError(_ error: Error)
    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceive(accountInfo: AccountInfo?, for chainAsset: ChainAsset, accountId: AccountId)
    func didReceiveWallet(wallet: MetaAccountModel)
    func didReceive(availableChainAssets: [ChainAsset])
}

protocol ChainAccountWireframeProtocol: ErrorPresentable,
    SheetAlertPresentable,
    ModalAlertPresenting,
    AuthorizationPresentable,
    ApplicationStatusPresentable {
    func close(view: ControllerBackedProtocol?)

    func showDetails(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

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
    func presentLockedInfo(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
    func presentCrossChainFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
    func showClaimCrowdloanRewardsFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol ChainAccountModuleInput: AnyObject {}

protocol ChainAccountModuleOutput: AnyObject {
    func updateTransactionHistory(for chainAsset: ChainAsset?)
}
