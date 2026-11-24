import XCTest
import UIKit
import BigInt
import RobinHood
import SoraFoundation
import SSFModels
import Web3
@testable import fearless

enum CovHChainAccountFixture {
    static func asset(id: String = "cov-asset", symbol: String = "COV", providers: [PurchaseProvider]? = nil) -> AssetModel {
        AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: 12,
            isUtility: true,
            isNative: true,
            purchaseProviders: providers
        )
    }

    static func hexId() -> String {
        (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased()
    }

    static func chain(
        id: String = CovHChainAccountFixture.hexId(),
        name: String = "Coverage chain",
        assets: Set<AssetModel> = [CovHChainAccountFixture.asset()],
        options: [ChainOptions]? = nil,
        parentId: String? = nil,
        disabled: Bool = false,
        externalApi: ChainModel.ExternalApiSet? = nil,
        minAppVersion: String? = nil
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: disabled,
            chainId: id,
            parentId: parentId,
            paraId: nil,
            name: name,
            assets: assets,
            xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://cov-h.invalid") ?? URL(fileURLWithPath: "/"), name: "cov", apikey: nil)],
            addressPrefix: 42,
            icon: nil,
            options: options,
            externalApi: externalApi,
            iosMinAppVersion: minAppVersion,
            identityChain: nil
        )
    }

    static func chainAsset(providers: [PurchaseProvider]? = nil, options: [ChainOptions]? = nil) -> ChainAsset {
        let asset = asset(providers: providers)
        return ChainAsset(chain: chain(assets: [asset], options: options), asset: asset)
    }

    static func bitcoinChainAsset() throws -> ChainAsset {
        let chain = UniversalWalletRegistry.bitcoinMainnetChainModel
        return ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first))
    }

    static func tairaChainAsset() throws -> ChainAsset {
        let chain = UniversalWalletRegistry.tairaChainModel
        return ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first))
    }

    static func wallet(extraAccounts: Set<ChainAccountModel> = []) -> MetaAccountModel {
        AccountGenerator.generateMetaAccount(with: extraAccounts)
    }

    static func bitcoinAccount() -> ChainAccountModel {
        ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: Data(repeating: 7, count: 32),
            publicKey: Data(repeating: 7, count: 33),
            cryptoType: 0,
            ethereumBased: false
        )
    }

    static func viewModel(name: String = "Wallet", mode: ChainAccountViewMode = .extended, address: String? = "address") -> ChainAccountViewModel {
        ChainAccountViewModel(
            walletName: name,
            selectedChainName: "Coverage chain",
            selectedChainIcon: nil,
            address: address,
            assetModel: nil,
            sendButtonVisible: true,
            buyButtonVisible: false,
            polkaswapButtonVisible: true,
            xcmButtomVisible: false,
            optionsButtonVisible: true,
            mode: mode
        )
    }

    static func actionName(_ action: ChainAction) -> String {
        switch action {
        case .copyAddress: return "copy"
        case .polkascan: return "polkascan"
        case .subscan: return "subscan"
        case .etherscan: return "etherscan"
        case .oklink: return "oklink"
        case .switchNode: return "switchNode"
        case .export: return "export"
        case .replace: return "replace"
        case .reefscan: return "reefscan"
        case .claimCrowdloanRewards: return "claim"
        case let .useStoredAccount(address): return "stored:\(address)"
        case .useWalletAccount: return "walletAccount"
        case .switchToPasswordAccount: return "passwordAccount"
        }
    }

    static func spin(timeout: TimeInterval = 3, until predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

final class CovHChainAccountViewSpy: UIViewController, ChainAccountViewProtocol {
    var states: [ChainAccountViewState] = []
    var balances: [ChainAccountBalanceViewModel?] = []
    var contentInsets: UIEdgeInsets = .zero
    var preferredContentHeight: CGFloat = 0
    var observable = ViewModelObserverContainer<ContainableObserver>()
    var contentView: UIView { view }

    func setContentInsets(_: UIEdgeInsets, animated _: Bool) {}
    func didReceiveState(_ state: ChainAccountViewState) { states.append(state) }
    func didReceive(balanceViewModel: ChainAccountBalanceViewModel?) { balances.append(balanceViewModel) }

    var loadedModels: [ChainAccountViewModel] {
        states.compactMap { state in
            if case let .loaded(model) = state { return model }
            return nil
        }
    }
}

final class CovHChainAccountInteractorSpy: ChainAccountInteractorInputProtocol {
    var chainAsset: ChainAsset
    var availableChainAssets: [ChainAsset] = []
    var calls: [String] = []
    var exportAddresses: [String] = []
    var updatedChains: [ChainModel] = []
    var claimAvailable = false

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    func setup() { calls.append("setup") }
    func getAvailableExportOptions(for address: String) { exportAddresses.append(address) }
    func update(chain: ChainModel) { updatedChains.append(chain) }
    func updateData() { calls.append("updateData") }
    func checkIsClaimAvailable() -> Bool { claimAvailable }
}

final class CovHChainAccountFactoryStub: ChainAccountViewModelFactoryProtocol {
    var wallets: [MetaAccountModel] = []
    var chainAssets: [ChainAsset] = []
    var modes: [ChainAccountViewMode] = []

    func buildChainAccountViewModel(chainAsset: ChainAsset, wallet: MetaAccountModel, mode: ChainAccountViewMode) -> ChainAccountViewModel {
        wallets.append(wallet)
        chainAssets.append(chainAsset)
        modes.append(mode)
        return CovHChainAccountFixture.viewModel(name: wallet.name, mode: mode)
    }
}

final class CovHChainAccountBalanceModuleSpy: BalanceInfoModuleInput {
    var infoTypes: [BalanceInfoType] = []
    func replace(infoType: BalanceInfoType) { infoTypes.append(infoType) }
}

final class CovHChainAccountModuleOutputSpy: ChainAccountModuleOutput {
    var updates: [ChainAsset?] = []
    func updateTransactionHistory(for chainAsset: ChainAsset?) { updates.append(chainAsset) }
}

final class CovHChainAccountWireframeSpy: ChainAccountWireframeProtocol {
    var calls: [String] = []
    var chainAssets: [ChainAsset] = []
    var buyItems: [[PurchaseAction]] = []
    var buyDelegates: [ModalPickerViewControllerDelegate] = []
    var purchaseActions: [PurchaseAction] = []
    var actionItems: [[ChainAction]] = []
    var actionCallbacks: [ModalPickerSelectionCallback] = []
    var replaceItems: [[ReplaceChainOption]] = []
    var replaceCallbacks: [ModalPickerSelectionCallback] = []
    var sheets: [SheetAlertPresentableViewModel] = []
    var exportOptions: [[ExportOption]] = []
    var exportAddresses: [String] = []
    var uniqueModels: [UniqueChainModel] = []
    var selectedChainIds: [ChainModel.Id?] = []
    var selectChainModels: [[ChainModel]?] = []
    var selectDelegates: [SelectNetworkDelegate?] = []
    var statusCount = 0

    func close(view _: ControllerBackedProtocol?) { calls.append("close") }
    func showDetails(from _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("details"); chainAssets.append(chainAsset)
    }

    func presentSendFlow(from _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("send"); chainAssets.append(chainAsset)
    }

    func presentReceiveFlow(from _: ControllerBackedProtocol?, asset _: AssetModel, chain _: ChainModel, wallet _: MetaAccountModel) {
        calls.append("receive")
    }

    func presentBuyFlow(from _: ControllerBackedProtocol?, items: [PurchaseAction], delegate: ModalPickerViewControllerDelegate) {
        calls.append("buy"); buyItems.append(items); buyDelegates.append(delegate)
    }

    func presentPurchaseWebView(from _: ControllerBackedProtocol?, action: PurchaseAction) {
        calls.append("purchase"); purchaseActions.append(action)
    }

    func presentChainActionsFlow(
        from _: ControllerBackedProtocol?, items: [ChainAction], chain _: ChainModel, callback: @escaping ModalPickerSelectionCallback
    ) {
        calls.append("actions"); actionItems.append(items); actionCallbacks.append(callback)
    }

    func presentNodeSelection(from _: ControllerBackedProtocol?, chain _: ChainModel) { calls.append("node") }
    func showExport(
        for address: String, chain _: ChainModel, options: [ExportOption], locale _: Locale?, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?
    ) {
        calls.append("export"); exportOptions.append(options); exportAddresses.append(address)
    }

    func showUniqueChainSourceSelection(
        from _: ControllerBackedProtocol?, items: [ReplaceChainOption], callback: @escaping ModalPickerSelectionCallback
    ) {
        calls.append("replace"); replaceItems.append(items); replaceCallbacks.append(callback)
    }

    func showCreate(uniqueChainModel: UniqueChainModel, from _: ControllerBackedProtocol?) {
        calls.append("create"); uniqueModels.append(uniqueChainModel)
    }

    func showImport(uniqueChainModel: UniqueChainModel, from _: ControllerBackedProtocol?) {
        calls.append("import"); uniqueModels.append(uniqueChainModel)
    }

    func showSelectNetwork(
        from _: ChainAccountViewProtocol?,
        wallet _: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    ) {
        calls.append("network"); selectedChainIds.append(selectedChainId); selectChainModels.append(chainModels); selectDelegates.append(delegate)
    }

    func showPolkaswap(from _: ChainAccountViewProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("polkaswap"); chainAssets.append(chainAsset)
    }

    func presentLockedInfo(from _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("locked"); chainAssets.append(chainAsset)
    }

    func presentCrossChainFlow(from _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("crossChain"); chainAssets.append(chainAsset)
    }

    func showClaimCrowdloanRewardsFlow(from _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("claim"); chainAssets.append(chainAsset)
    }

    func presentStatus(with _: ApplicationStatusAlertEvent, animated _: Bool) { statusCount += 1 }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { calls.append("error"); return true }
    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
}

final class CovHChainAccountSelectNetworkView: UIViewController, SelectNetworkViewInput {
    func didReload() {}
    func bind(viewModel _: TextSearchViewModel?) {}
}

final class CovHChainAccountEventCenterSpy: EventCenterProtocol {
    var observers: [EventVisitorProtocol] = []
    var events: [EventProtocol] = []
    func notify(with event: EventProtocol) { events.append(event) }
    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) { observers.append(observer) }
    func remove(observer _: EventVisitorProtocol) {}
}

final class CovHChainAccountAssetFetchingStub: ChainAssetFetchingProtocol {
    var result: Result<[ChainAsset], Error>? = .success([])
    var filters: [[ChainAssetsFetching.Filter]] = []

    func fetch(
        shouldUseCache _: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        self.filters.append(filters)
        completionBlock(result)
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool, filters _: [ChainAssetsFetching.Filter], sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        let operation = BaseOperation<[ChainAsset]>()
        operation.result = .success([])
        return operation
    }

    func fetchAwait(
        shouldUseCache _: Bool, filters _: [ChainAssetsFetching.Filter], sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        []
    }
}

final class CovHChainAccountExportOptionsStub: AvailableExportOptionsProviderProtocol {
    var options: [ExportOption] = [.mnemonic, .keystore]
    var requests: [(AccountId?, Bool)] = []

    func getAvailableExportOptions(for _: MetaAccountModel, accountId: AccountId?, isEthereum: Bool) -> [ExportOption] {
        requests.append((accountId, isEthereum))
        return options
    }

    func getAvailableExportOptions(for _: MetaAccountModel, accountId: AccountId?) -> [ExportOption] {
        requests.append((accountId, false))
        return options
    }
}

final class CovHChainAccountBalanceAdapterSpy: WalletBalanceSubscriptionAdapterProtocol {
    var chainAssetSubscriptions: [ChainAsset] = []
    func subscribeWalletBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeWalletsBalances(listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetBalance(wallet _: MetaAccountModel, chainAsset: ChainAsset, listener _: WalletBalanceSubscriptionListener) {
        chainAssetSubscriptions.append(chainAsset)
    }

    func subscribeChainAssetsBalance(chainAssets _: [ChainAsset], wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeNetworkManagementBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {}
}

final class CovHChainAccountRemoteServiceStub: AccountInfoRemoteService {
    var accountInfo: AccountInfo?
    var error: Error?
    var requests: [ChainAsset] = []

    func fetchAccountInfos(for _: ChainModel, wallet _: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] { [:] }

    func fetchAccountInfo(for chainAsset: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? {
        requests.append(chainAsset)
        if let error { throw error }
        return accountInfo
    }
}

final class CovHChainAccountRegistryStub: ChainRegistryProtocol {
    var runtimeRequests: [ChainModel.Id] = []
    var availableChainIds: Set<ChainModel.Id>? { [] }
    var availableChains: [ChainModel] { [] }
    var chainsTypesMap: [String: Data] { [:] }
    func resetConnection(for _: ChainModel.Id) {}
    func retryConnection(for _: ChainModel.Id) {}
    func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }
    func getEthereumConnection(for _: ChainModel.Id) -> Web3.Eth? { nil }
    func getTonApiClientFactory() throws -> TonAPIClientFactory { throw NSError(domain: "cov-h", code: 1) }
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtimeRequests.append(chainId)
        return nil
    }

    func getChain(for _: ChainModel.Id) -> ChainModel? { nil }
    func chainsSubscribe(_: AnyObject, runningInQueue _: DispatchQueue, updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void) {}
    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

final class CovHChainAccountOutputSpy: ChainAccountInteractorOutputProtocol {
    private let lock = NSLock()
    private var storedEvents: [String] = []
    private var storedExportOptions: [[ExportOption]] = []
    private var storedAccountInfos: [AccountInfo?] = []
    private var storedAvailable: [[ChainAsset]] = []
    private var storedWallets: [MetaAccountModel] = []
    private var storedUpdates: [ChainAsset] = []
    private var storedMinimums: [Result<BigUInt, Error>] = []

    var events: [String] { locked { storedEvents } }
    var exportOptions: [[ExportOption]] { locked { storedExportOptions } }
    var accountInfos: [AccountInfo?] { locked { storedAccountInfos } }
    var availableChainAssets: [[ChainAsset]] { locked { storedAvailable } }
    var wallets: [MetaAccountModel] { locked { storedWallets } }
    var updatedChainAssets: [ChainAsset] { locked { storedUpdates } }
    var minimumBalances: [Result<BigUInt, Error>] { locked { storedMinimums } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func record(_ event: String, _ body: () -> Void = {}) {
        locked {
            storedEvents.append(event)
            body()
        }
    }

    func didReceiveExportOptions(options: [ExportOption]) { record("export") { storedExportOptions.append(options) } }
    func didUpdate(chainAsset: ChainAsset) { record("update") { storedUpdates.append(chainAsset) } }
    func didReceiveBalanceLocks(_: Decimal?) { record("locks") }
    func didReceiveBalanceLocksError(_: Error) { record("locksError") }
    func didReceiveWalletBalancesResult(_: WalletBalancesResult) { record("balances") }
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) { record("minimum") { storedMinimums.append(result) } }
    func didReceive(accountInfo: AccountInfo?, for _: ChainAsset, accountId _: AccountId) {
        record("accountInfo") { storedAccountInfos.append(accountInfo) }
    }

    func didReceiveWallet(wallet: MetaAccountModel) { record("wallet") { storedWallets.append(wallet) } }
    func didReceive(availableChainAssets: [ChainAsset]) { record("available") { storedAvailable.append(availableChainAssets) } }
    func didReceiveAssetFrozen(_: Decimal?) { record("frozen") }
    func didReceiveAssetFrozenError(_: Error) { record("frozenError") }
}
