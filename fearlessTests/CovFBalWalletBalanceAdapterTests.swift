import BigInt
import Foundation
import SSFModels
import XCTest
@testable import fearless

final class CovFBalBalanceListener: WalletBalanceSubscriptionListener {
    let type: WalletBalanceListenerType

    private let lock = NSLock()
    private var storedResults: [WalletBalancesResult] = []

    init(_ type: WalletBalanceListenerType) {
        self.type = type
    }

    func handle(result: WalletBalancesResult) {
        lock.lock()
        storedResults.append(result)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedResults.count
    }

    var lastBalances: WalletBalanceInfos? {
        lock.lock()
        defer { lock.unlock() }
        guard case let .success(balances)? = storedResults.last else {
            return nil
        }
        return balances
    }
}

/// `WalletBalanceSubscriptionAdapter` has only a private initializer, so these tests drive the
/// process-wide instance with wallets and networks of their own (random ids) and unsubscribe after.
class CovFBalWalletBalanceAdapterCase: XCTestCase {
    var adapter: WalletBalanceSubscriptionAdapter { WalletBalanceSubscriptionAdapter.shared }
    private var listeners: [CovFBalBalanceListener] = []

    override class func setUp() {
        super.setUp()
        // Let the instance's initial wallet and network load finish before the tests change its state.
        _ = WalletBalanceSubscriptionAdapter.shared
        covFBalSettle(0.5)
    }

    override func tearDown() {
        listeners.forEach { adapter.unsubscribe(listener: $0) }
        listeners = []
        super.tearDown()
    }

    func makeListener(_ type: WalletBalanceListenerType) -> CovFBalBalanceListener {
        let listener = CovFBalBalanceListener(type)
        listeners.append(listener)
        return listener
    }

    func track(_ wallet: fearless.MetaAccountModel) {
        adapter.processSelectedAccountChanged(event: SelectedAccountChanged(account: wallet))
    }

    func visibilityChange(for walletId: String) -> AssetVisibilityPreferenceChangedEvent {
        AssetVisibilityPreferenceChangedEvent(
            walletId: walletId,
            assetKey: AssetKey(ecosystem: "substrate", chainId: covFBalChainId(), assetId: "0"),
            preference: .hidden
        )
    }

    func accountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(nonce: 1, consumers: 0, providers: 1, data: AccountData(free: free, reserved: 0, frozen: 0, flags: 0))
    }
}

final class CovFBalWalletBalanceAdapterTests: CovFBalWalletBalanceAdapterCase {
    func testEverySubscriptionDeliversTheCurrentBalanceRightAway() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovFBalChains.chainAsset()
        let walletListener = makeListener(.wallet(wallet: wallet))
        let chainAssetListener = makeListener(.chainAsset(wallet: wallet, chainAsset: chainAsset))
        let chainAssetsListener = makeListener(.chainAssets(chainAssets: [chainAsset], wallet: wallet))
        let networkListener = makeListener(.networkManagement(wallet: wallet))
        let walletsListener = makeListener(.wallets)

        adapter.subscribeWalletBalance(wallet: wallet, listener: walletListener)
        adapter.subscribeChainAssetBalance(wallet: wallet, chainAsset: chainAsset, listener: chainAssetListener)
        adapter.subscribeChainAssetsBalance(chainAssets: [chainAsset], wallet: wallet, listener: chainAssetsListener)
        adapter.subscribeNetworkManagementBalance(wallet: wallet, listener: networkListener)
        adapter.subscribeWalletsBalances(listener: walletsListener)

        for listener in [walletListener, chainAssetListener, chainAssetsListener, networkListener] {
            XCTAssertEqual(listener.count, 1)
            let balance = try XCTUnwrap(listener.lastBalances?[wallet.metaId])
            XCTAssertEqual(balance.currency, wallet.selectedCurrency)
        }
        let chainAssetBalance = try XCTUnwrap(chainAssetListener.lastBalances?[wallet.metaId])
        XCTAssertEqual(chainAssetListener.lastBalances?.count, 1)
        XCTAssertEqual(chainAssetBalance.totalFiatValue, 0)
        XCTAssertEqual(chainAssetBalance.enabledAssetFiatBalance, 0)
        XCTAssertNil(networkListener.lastBalances?[wallet.metaId]?.filteredPart)
        XCTAssertGreaterThanOrEqual(walletsListener.count, 1)
        XCTAssertNotNil(walletsListener.lastBalances)
        XCTAssertNil(walletsListener.lastBalances?[wallet.metaId])
    }

    func testSingleNetworkFilterAddsTheFilteredPartToTheHeaderBalance() throws {
        let chainId = covFBalChainId()
        let wallet = AccountGenerator.generateMetaAccount().replacingNetworkManagmentFilter(chainId)
        let networkListener = makeListener(.networkManagement(wallet: wallet))

        adapter.subscribeNetworkManagementBalance(wallet: wallet, listener: networkListener)

        let part = try XCTUnwrap(networkListener.lastBalances?[wallet.metaId]?.filteredPart)
        XCTAssertEqual(part.filter.identifier, chainId)
        XCTAssertEqual(part.fiatBalance, 0)
        XCTAssertNil(part.networkName)
    }

    func testAccountInfoChangesAreStoredAndRebuildTrackedWallets() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        let chainAsset = CovFBalChains.chainAsset()
        let untouched = CovFBalChains.chainAsset()
        let key = chainAsset.uniqueKey(accountId: accountId)
        let info = accountInfo(free: 5)
        track(wallet)
        let walletListener = makeListener(.wallet(wallet: wallet))
        adapter.subscribeWalletBalance(wallet: wallet, listener: walletListener)
        covFBalSettle()
        let before = walletListener.count

        adapter.handleAccountInfo(result: .success(info), accountId: accountId, chainAsset: chainAsset)

        XCTAssertTrue(covFBalEventually { walletListener.count > before })
        let rebuilt = try XCTUnwrap(walletListener.lastBalances?[wallet.metaId])
        XCTAssertEqual(rebuilt.accountInfos[key] ?? nil, info)

        adapter.handleAccountInfo(result: .success(info), accountId: accountId, chainAsset: chainAsset)
        adapter.handleAccountInfo(result: .success(nil), accountId: accountId, chainAsset: untouched)
        adapter.handleAccountInfo(result: .failure(CovFBalError.expected), accountId: accountId, chainAsset: chainAsset)
        covFBalSettle()

        let chainAssetListener = makeListener(.chainAsset(wallet: wallet, chainAsset: chainAsset))
        adapter.subscribeChainAssetBalance(wallet: wallet, chainAsset: chainAsset, listener: chainAssetListener)
        let stored = try XCTUnwrap(chainAssetListener.lastBalances?[wallet.metaId])
        XCTAssertEqual(stored.accountInfos[key] ?? nil, info)
        XCTAssertNil(stored.accountInfos[untouched.uniqueKey(accountId: accountId)] ?? nil)
    }

    func testMetaAccountChangesRebuildOnlyWhenTheyAffectTheBalance() {
        let wallet = AccountGenerator.generateMetaAccount()
        let euroWallet = wallet.replacingCurrency(Currency.euro())
        let filteredWallet = euroWallet.replacingNetworkManagmentFilter("popular")
        track(wallet)
        let walletsListener = makeListener(.wallets)
        adapter.subscribeWalletsBalances(listener: walletsListener)
        covFBalSettle()

        var count = walletsListener.count
        adapter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: euroWallet))
        XCTAssertGreaterThan(walletsListener.count, count)
        XCTAssertEqual(walletsListener.lastBalances?[wallet.metaId]?.currency, Currency.euro())

        count = walletsListener.count
        adapter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: filteredWallet))
        XCTAssertGreaterThan(walletsListener.count, count)

        count = walletsListener.count
        adapter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: filteredWallet))
        adapter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: AccountGenerator.generateMetaAccount()))
        XCTAssertEqual(walletsListener.count, count)

        let withChainAccount = filteredWallet.replacingChainAccounts([AccountGenerator.generateChainAccount()])
        adapter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: withChainAccount))
        XCTAssertGreaterThan(walletsListener.count, count)
    }

    func testSubscribingWithANewCurrencyUpdatesTheTrackedWallet() {
        let wallet = AccountGenerator.generateMetaAccount()
        let euroWallet = wallet.replacingCurrency(Currency.euro())
        track(wallet)
        let walletsListener = makeListener(.wallets)
        let walletListener = makeListener(.wallet(wallet: euroWallet))
        adapter.subscribeWalletsBalances(listener: walletsListener)

        adapter.subscribeWalletBalance(wallet: euroWallet, listener: walletListener)

        XCTAssertGreaterThanOrEqual(walletListener.count, 1)
        XCTAssertEqual(walletListener.lastBalances?[wallet.metaId]?.currency, Currency.euro())

        covFBalSettle()
        let count = walletsListener.count
        adapter.processAssetVisibilityPreferenceChanged(event: visibilityChange(for: wallet.metaId))

        XCTAssertGreaterThan(walletsListener.count, count)
        XCTAssertEqual(walletsListener.lastBalances?[wallet.metaId]?.currency, Currency.euro())
    }
}

final class CovFBalWalletBalanceEventsTests: CovFBalWalletBalanceAdapterCase {
    func testVisibilityChangesNotifyOnlyListenersOfTheTrackedWallet() {
        let wallet = AccountGenerator.generateMetaAccount()
        let stranger = AccountGenerator.generateMetaAccount()
        let chainAsset = CovFBalChains.chainAsset()
        track(wallet)
        let walletListener = makeListener(.wallet(wallet: wallet))
        let networkListener = makeListener(.networkManagement(wallet: wallet))
        let chainAssetListener = makeListener(.chainAsset(wallet: wallet, chainAsset: chainAsset))
        let chainAssetsListener = makeListener(.chainAssets(chainAssets: [chainAsset], wallet: wallet))
        let strangerListener = makeListener(.wallet(wallet: stranger))
        adapter.subscribeWalletBalance(wallet: wallet, listener: walletListener)
        adapter.subscribeNetworkManagementBalance(wallet: wallet, listener: networkListener)
        adapter.subscribeChainAssetBalance(wallet: wallet, chainAsset: chainAsset, listener: chainAssetListener)
        adapter.subscribeChainAssetsBalance(chainAssets: [chainAsset], wallet: wallet, listener: chainAssetsListener)
        adapter.subscribeWalletBalance(wallet: stranger, listener: strangerListener)
        covFBalSettle()
        let walletCount = walletListener.count
        let networkCount = networkListener.count

        adapter.processAssetVisibilityPreferenceChanged(event: visibilityChange(for: stranger.metaId))
        adapter.processRemoteAccountInfoUpdated(event: RemoteAccountInfoUpdatedEvent(walletId: wallet.metaId, chainId: covFBalChainId()))

        XCTAssertEqual(walletListener.count, walletCount)
        XCTAssertEqual(networkListener.count, networkCount)

        adapter.processAssetVisibilityPreferenceChanged(event: visibilityChange(for: wallet.metaId))

        XCTAssertGreaterThan(walletListener.count, walletCount)
        XCTAssertGreaterThan(networkListener.count, networkCount)
        XCTAssertNotNil(networkListener.lastBalances?[wallet.metaId])
        XCTAssertEqual(chainAssetListener.count, 1)
        XCTAssertEqual(chainAssetsListener.count, 1)
        XCTAssertEqual(strangerListener.count, 1)
    }

    func testKnownSelectedWalletIsKeptAndLogoutForgetsTrackedWallets() {
        let wallet = AccountGenerator.generateMetaAccount()
        track(wallet)
        track(wallet)
        let walletListener = makeListener(.wallet(wallet: wallet))
        adapter.subscribeWalletBalance(wallet: wallet, listener: walletListener)
        covFBalSettle()

        var count = walletListener.count
        adapter.processAssetVisibilityPreferenceChanged(event: visibilityChange(for: wallet.metaId))
        XCTAssertGreaterThan(walletListener.count, count)

        adapter.processLogout()
        count = walletListener.count
        adapter.processAssetVisibilityPreferenceChanged(event: visibilityChange(for: wallet.metaId))

        XCTAssertEqual(walletListener.count, count)
    }

    func testPriceUpdatesAndChainSyncKeepNotifyingTrackedWallets() {
        let wallet = AccountGenerator.generateMetaAccount()
        track(wallet)
        let walletListener = makeListener(.wallet(wallet: wallet))
        adapter.subscribeWalletBalance(wallet: wallet, listener: walletListener)
        covFBalSettle()
        let before = walletListener.count

        adapter.processPricesUpdated()

        XCTAssertTrue(covFBalEventually { walletListener.count > before })
        XCTAssertNotNil(walletListener.lastBalances?[wallet.metaId])

        adapter.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [], removedChains: []))
        covFBalSettle(0.5)
        let afterSync = walletListener.count
        adapter.processAssetVisibilityPreferenceChanged(event: visibilityChange(for: wallet.metaId))

        XCTAssertGreaterThan(walletListener.count, afterSync)
    }

    func testUnsubscribedListenerStopsReceivingBalances() {
        let wallet = AccountGenerator.generateMetaAccount()
        track(wallet)
        let kept = makeListener(.wallet(wallet: wallet))
        let removed = makeListener(.wallet(wallet: wallet))
        adapter.subscribeWalletBalance(wallet: wallet, listener: kept)
        adapter.subscribeWalletBalance(wallet: wallet, listener: removed)
        covFBalSettle()

        adapter.unsubscribe(listener: removed)
        covFBalSettle()
        let keptCount = kept.count
        let removedCount = removed.count
        adapter.processAssetVisibilityPreferenceChanged(event: visibilityChange(for: wallet.metaId))

        XCTAssertGreaterThan(kept.count, keptCount)
        XCTAssertEqual(removed.count, removedCount)
    }
}
