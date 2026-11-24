import XCTest
import UIKit
import BigInt
import SoraFoundation
import SSFModels
import RobinHood
@testable import fearless

/// Lane-J (CovJSel) fixtures shared by the asset and network selection tests.
enum CovJSelFixture {
    static func manager() throws -> LocalizationManager {
        try XCTUnwrap(LocalizationManager(localization: "en"))
    }

    /// A wallet with a substrate account and no Ethereum account: Ethereum-based chains have no account in it.
    static func substrateWallet() -> MetaAccountModel {
        AccountGenerator.generateMetaAccount().replacingEthereumAddress(nil)
    }

    static func chain(
        id: String = UUID().uuidString,
        name: String,
        rank: UInt16? = nil,
        icon: URL? = nil,
        options: [ChainOptions]? = nil,
        assets: [AssetModel]
    ) -> ChainModel {
        let chain = ChainModel(
            rank: rank,
            disabled: false,
            chainId: id,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            types: nil,
            icon: icon,
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        chain.assets = Set(assets)
        return chain
    }

    static func asset(_ id: String, symbol: String? = nil, utility: Bool = true, icon: URL? = nil, priceId: String? = nil) -> AssetModel {
        CovJFixture.asset(id: id, symbol: symbol ?? id.uppercased(), precision: 12, isUtility: utility, icon: icon, priceId: priceId)
    }

    static func units(_ value: Int) -> BigUInt {
        BigUInt(value) * BigUInt(10).power(12)
    }

    static func info(free: BigUInt, reserved: BigUInt = 0, frozen: BigUInt = 0) -> AccountInfo {
        AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: free, reserved: reserved, frozen: frozen))
    }

    static func key(_ chainAsset: ChainAsset, wallet: MetaAccountModel) throws -> ChainAssetKey {
        let accountId = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId)
        return chainAsset.uniqueKey(accountId: accountId)
    }

    static func token(_ value: Decimal, _ asset: AssetModel, locale: Locale, usage: NumberFormatterUsageCase = .listCrypto) -> String? {
        AssetBalanceFormatterFactory().createTokenFormatter(for: asset.displayInfo, usageCase: usage).value(for: locale).stringFromDecimal(value)
    }

    static func fiat(_ value: Decimal, currency: Currency, locale: Locale, usage: NumberFormatterUsageCase = .fiat) -> String? {
        let info = AssetBalanceDisplayInfo.forCurrency(currency)
        return AssetBalanceFormatterFactory().createTokenFormatter(for: info, usageCase: usage).value(for: locale).stringFromDecimal(value)
    }

    /// Registers a positive price for `priceId` in the process-wide exact price cache (unique ids never collide).
    static func registerPrice(_ price: String, priceId: String, currency: Currency) {
        ExactAssetPriceCache.shared.upsert([
            PriceData(currencyId: currency.id, priceId: priceId, price: price, fiatDayChange: nil, coingeckoPriceId: priceId)
        ])
    }

    /// A remote image whose source is the bundled Bitcoin logo, so loading it never touches the network.
    static var offlineIcon: RemoteImageViewModel {
        RemoteImageViewModel(url: UniversalWalletRegistry.bitcoinIconURL)
    }
}

/// A selection-list view (chain, network and asset pickers) that records reloads and search bindings.
final class CovJSelListViewSpy: ChainSelectionViewProtocol, SelectNetworkViewInput, SelectAssetViewInput {
    let controller: UIViewController
    var isSetup = true
    private(set) var reloadCount = 0
    private(set) var boundSearch: [TextSearchViewModel?] = []

    init(controller: UIViewController = UIViewController()) {
        self.controller = controller
    }

    func didReload() {
        reloadCount += 1
    }

    func bind(viewModel: TextSearchViewModel?) {
        boundSearch.append(viewModel)
    }
}

/// Records account-info subscriptions instead of opening storage providers; `deliver` plays a balance back.
final class CovJSelAccountInfoAdapterStub: AccountInfoSubscriptionAdapterProtocol {
    private let lock = NSLock()
    private var storedSubscriptions: [[ChainAsset]] = []
    private var storedQueues: [DispatchQueue?] = []
    private weak var handler: AccountInfoSubscriptionAdapterHandler?

    var subscriptions: [[ChainAsset]] {
        lock.lock()
        defer { lock.unlock() }
        return storedSubscriptions
    }

    var queues: [DispatchQueue?] {
        lock.lock()
        defer { lock.unlock() }
        return storedQueues
    }

    func subscribe(
        chainAsset: ChainAsset,
        accountId _: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        record([chainAsset], handler: handler, queue: queue)
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        record(chainsAssets, handler: handler, queue: queue)
    }

    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: MetaAccountModel) {}

    func deliver(_ result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        lock.lock()
        let target = handler
        lock.unlock()
        target?.handleAccountInfo(result: result, accountId: accountId, chainAsset: chainAsset)
    }

    private func record(_ chainAssets: [ChainAsset], handler: AccountInfoSubscriptionAdapterHandler?, queue: DispatchQueue?) {
        lock.lock()
        storedSubscriptions.append(chainAssets)
        storedQueues.append(queue)
        self.handler = handler
        lock.unlock()
    }
}

/// A router for the selection modules that only dismiss: records every dismissal and every presented error.
final class CovJSelDismissSpy: CovJSheetSpy, SelectAssetRouterInput, MultiSelectNetworksRouterInput, AssetListSearchRouterInput,
    MultichainAssetSelectionRouterInput {
    private(set) var dismissed: [ControllerBackedProtocol?] = []

    func dismiss(view: ControllerBackedProtocol?) {
        dismissed.append(view)
    }
}

/// Answers `fetch` with a fixed result and records the filters it was asked for.
final class CovJSelChainAssetFetchingStub: ChainAssetFetchingProtocol {
    var result: Result<[ChainAsset], Error>?
    private(set) var requestedFilters: [[ChainAssetsFetching.Filter]] = []

    init(result: Result<[ChainAsset], Error>?) {
        self.result = result
    }

    func fetch(
        shouldUseCache _: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        requestedFilters.append(filters)
        completionBlock(result)
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        let operation = BaseOperation<[ChainAsset]>()
        operation.result = result
        return operation
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        switch result {
        case let .success(assets):
            return assets
        case let .failure(error):
            throw error
        case .none:
            return []
        }
    }
}

final class CovJSelSelectAssetInputSpy: SelectAssetModuleInput {
    private(set) var updates: [[ChainAsset]] = []

    func update(with chainAssets: [ChainAsset]) {
        updates.append(chainAssets)
    }
}

final class CovJSelSelectAssetOutputSpy: SelectAssetModuleOutput {
    private(set) var completions: [(chainAsset: ChainAsset?, tag: Int?)] = []

    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?) {
        completions.append((chainAsset, contextTag))
    }
}
