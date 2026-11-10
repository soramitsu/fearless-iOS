import SSFModels
import SSFUtils

typealias WalletMainContainerModuleCreationResult = (
    view: WalletMainContainerViewInput,
    input: WalletMainContainerModuleInput
)

protocol WalletMainContainerViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel)
    func didReceiveNftAvailability(isNftAvailable: Bool)
    func didReceive(syncUpdate: WalletSyncUpdate)
}

protocol WalletMainContainerViewOutput: AnyObject {
    func didLoad(view: WalletMainContainerViewInput)
    func didTapOnSwitchWallet()
    func didTapOnQR()
    func didTapSearch()
    func didTapSelectNetwork()
    func didTapOnBalance()
    func addressDidCopied()
    func didTapAccountScore()
    func didTapHomeAction(_ action: WalletHomeAction)
}

protocol WalletMainContainerInteractorInput: AnyObject {
    func setup(with output: WalletMainContainerInteractorOutput)
    func walletConnect(uri: String) async throws
    func acknowledge(_ notice: StoredWalletRecordsNotice)
    func acknowledgeUniversalWalletPasswordNotice()
    func switchNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount])
    func acknowledgeOldAddressArrivals(_ arrivals: [UniversalWalletOldAddressArrival])
}

protocol WalletMainContainerInteractorOutput: AnyObject {
    func didReceiveAccount(_ account: MetaAccountModel)
    func didReceiveSelected(tuple: (select: NetworkManagmentFilter, chains: [ChainModel]))
    func didReceiveError(_ error: Error)
    func didReceiveControllerAccountIssue(issue: ControllerAccountIssue, hasStashItem: Bool)
    func didReceiveStashAccountIssue(address: String)
    func didReceiveNftAvailability(isNftAvailable: Bool)
    func didReceiveStoredWalletRecordsNotices(_ notices: [StoredWalletRecordsNotice])
    /// The selected wallet has a password that some of its universal accounts do not use.
    func didReceiveUniversalWalletNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount])
    func didReceiveUniversalWalletSwitchOutcomes(
        _ outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount]
    )
    /// Funds reached old addresses while the wallet keeps its password-protected ones.
    func didReceiveUniversalWalletOldAddressArrivals(_ arrivals: [UniversalWalletOldAddressArrival])
    func didReceive(syncUpdate: WalletSyncUpdate)
}

protocol WalletMainContainerRouterInput: SheetAlertPresentable, ErrorPresentable, ApplicationStatusPresentable, AccountManagementPresentable, AccountScorePresentable {
    func showWalletManagment(
        from view: WalletMainContainerViewInput?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
    func showScanQr(from view: WalletMainContainerViewInput?, moduleOutput: ScanQRModuleOutput)
    func showSearch(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel)
    func showSelectNetwork(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel,
        delegate: NetworkManagmentModuleOutput?
    )
    func showSelectCurrency(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel
    )

    func showSendFlow(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData
    )

    func showControllerAccountFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showMainStaking(from view: WalletMainContainerViewInput?)
    func showWalletDetails(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel)
    func showAssetPicker(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel,
        action: WalletHomeAction,
        output: SelectAssetModuleOutput
    )
    func showReceive(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel, chainAsset: ChainAsset)
    func showAssetDetails(from view: WalletMainContainerViewInput?, chainAsset: ChainAsset)
    func showSwap(from view: WalletMainContainerViewInput?)
}

protocol WalletMainContainerModuleInput: AnyObject {}

protocol WalletMainContainerModuleOutput: AnyObject {}

// MARK: - Sun-lit wallet home

/// The wallet screen's round actions (sun-lit redesign). Raw values tag the asset picker's answer.
enum WalletHomeAction: Int, CaseIterable {
    case send = 1
    case receive
    case buy
    case swap
}

/// Chain catalog and connection activity that the hero sun shows. UI only: it is read from the events the
/// chain registry already posts.
enum WalletSyncUpdate: Equatable {
    case catalog(running: Bool)
    case catalogFailed
    case connection(chainId: String, FWSyncTracker.Connection)

    /// A connection still trying is syncing; one past the reconnect limit, or not reachable, is unreachable.
    /// A socket that has not started yet counts as connecting, so a cold start never flashes a failure.
    static func connection(for state: WebSocketEngine.State) -> FWSyncTracker.Connection {
        switch state {
        case .connected:
            return .connected
        case let .connecting(attempt), let .waitingReconnection(attempt):
            return attempt > NetworkConstants.websocketReconnectAttemptsLimit ? .unreachable : .connecting
        case .notConnected:
            return .connecting
        case .notReachable:
            return .unreachable
        }
    }
}

extension WalletMainContainerViewInput {
    func didReceive(syncUpdate _: WalletSyncUpdate) {}
}

extension WalletMainContainerViewOutput {
    func didTapHomeAction(_: WalletHomeAction) {}
}

extension WalletMainContainerInteractorOutput {
    func didReceive(syncUpdate _: WalletSyncUpdate) {}
}
