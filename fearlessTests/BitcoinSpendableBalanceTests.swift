import XCTest
import BigInt
import SSFModels
import SSFStorageQueryKit
import SSFUtils
@testable import fearless

/// IOSUX-3 B2: the portfolio counts everything the wallet owns, while Send offers only what
/// the planner can spend (confirmed coins no mempool transaction spends). Before the fix both
/// read confirmed + mempool, so "Max" right after receiving or sending failed.
final class BitcoinSpendableBalanceTests: XCTestCase {
    private var ledger: BitcoinTestLedger!
    private var wallet: MetaAccountModel!
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        ledger = BitcoinTestLedger()
        wallet = try BitcoinTestWallet.wallet()
        suiteName = "BitcoinSpendableBalanceTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMempoolIncomingCountsInTotalButNotSendAvailable() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 300_000)
        ledger.fund(BitcoinTestWallet.address, sats: 200_000, confirmed: false)

        let info = try await accountInfo()

        XCTAssertEqual(info.data.total, 500_000, "The portfolio shows everything the wallet owns")
        XCTAssertEqual(info.data.sendAvailable, 300_000, "Send offers only confirmed coins")
        XCTAssertEqual(info.data.frozen, 200_000, "The rest is pending confirmation")
    }

    func testOwnPendingChangeNotSpendableUntilConfirmed() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 1_000_000)
        let service = makeTransferService()
        let transfer = BitcoinTestWallet.transfer(sats: 250_000)
        let fee = try await service.estimateFee(for: transfer)
        _ = try await service.submit(transfer: transfer)
        let change = 1_000_000 - 250_000 - Int64(fee)

        let pending = try await accountInfo()
        XCTAssertEqual(pending.data.total, BigUInt(UInt64(change)))
        XCTAssertEqual(pending.data.sendAvailable, 0, "The change waits for its first confirmation")

        ledger.confirmAll()
        let confirmed = try await accountInfo()
        XCTAssertEqual(confirmed.data.total, BigUInt(UInt64(change)))
        XCTAssertEqual(confirmed.data.sendAvailable, BigUInt(UInt64(change)))
        XCTAssertEqual(confirmed.data.frozen, 0)
    }

    /// "Max" asks for the fee of the whole spendable balance first, then sends the balance minus
    /// that fee. The transaction spends only confirmed coins, has no change and pays exactly
    /// the fee that was shown.
    func testSendAllUsesConfirmedSpendable() async throws {
        let confirmedCoin = ledger.fund(BitcoinTestWallet.address, sats: 300_000)
        ledger.fund(BitcoinTestWallet.address, sats: 200_000, confirmed: false)
        let sendAvailable = try await accountInfo().data.sendAvailable
        let service = makeTransferService()

        let maxFee = try await service.estimateFee(for: BitcoinTestWallet.transfer(sats: Int64(sendAvailable)))
        let maxAmount = Int64(sendAvailable) - Int64(maxFee)
        let transfer = BitcoinTestWallet.transfer(sats: maxAmount)
        let quotedFee = try await service.estimateFee(for: transfer)
        let txid = try await service.submit(transfer: transfer)

        XCTAssertEqual(quotedFee, maxFee)
        let sent = try ParsedBitcoinTransaction(hex: XCTUnwrap(ledger.broadcasts.last))
        XCTAssertEqual(sent.txid, txid)
        XCTAssertEqual(sent.inputs, [confirmedCoin], "An unconfirmed coin is never spent")
        XCTAssertEqual(sent.outputs.count, 1, "Sending everything leaves no change")
        XCTAssertEqual(sent.outputs.first?.valueSats, maxAmount)
        XCTAssertEqual(ledger.fee(of: sent), Int64(quotedFee))
    }

    func testMaxAboveWhatTheCoinsCanPayIsRefused() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 300_000)
        let service = makeTransferService()

        do {
            _ = try await service.estimateFee(for: BitcoinTestWallet.transfer(sats: 300_001))
            XCTFail("Expected more than the spendable balance to be refused")
        } catch {
            XCTAssertEqual(error as? BitcoinUtxoSelectionError, .insufficientFunds)
        }
    }

    /// The retained balance shown while a refresh fails is what the wallet owns, so a payment
    /// waiting for its first block does not vanish from the portfolio when offline.
    func testRetainedBalanceKeepsPendingValue() throws {
        let chain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let chainAsset = try XCTUnwrap(chain.chainAssets.first)
        let info = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 500_000, reserved: .zero, frozen: 200_000)
        )

        RemoteLastKnownBalanceStore.save(
            [chainAsset.chainAssetId: info],
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        let loaded = RemoteLastKnownBalanceStore.load(chain: chain, walletId: wallet.metaId, userDefaults: defaults)

        XCTAssertEqual(loaded[chainAsset.chainAssetId]??.data.total, 500_000)
    }

    /// Builds use the same key and plain decimal string as the TestFlight 4.2.0 builds wrote
    /// (`portfolio.remote.last_known_balance:<wallet>:<ecosystem>:<chain>:<asset>`), so a
    /// balance retained by an earlier build still loads after the upgrade.
    func testRetainedBalanceWrittenByAnEarlierBuildStillLoads() throws {
        let chain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let chainAsset = try XCTUnwrap(chain.chainAssets.first)
        let assetKey = chainAsset.assetKey
        defaults.set(
            "123456",
            forKey: [
                "portfolio.remote.last_known_balance",
                wallet.metaId,
                assetKey.ecosystem,
                assetKey.chainId,
                assetKey.assetId
            ].joined(separator: ":")
        )

        let loaded = RemoteLastKnownBalanceStore.load(chain: chain, walletId: wallet.metaId, userDefaults: defaults)

        XCTAssertEqual(loaded[chainAsset.chainAssetId]??.data.total, 123_456)
    }

    /// The confirm screen shows the fee with the rate of the exact quote ("2 sat/vB").
    func testFeeSubscriptionReportsTheQuotedRateWithTheFee() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 300_000)
        ledger.feeEstimates = ["2": 3.5]
        let service = makeTransferService()
        let listener = FeeRateListenerSpy()
        let received = expectation(description: "fee with rate")
        listener.onFee = { received.fulfill() }

        service.subscribeForFee(transfer: BitcoinTestWallet.transfer(sats: 100_000), listener: listener)
        await fulfillment(of: [received], timeout: 10)

        XCTAssertEqual(listener.rate, 3.5)
        XCTAssertEqual(listener.fee, BigUInt(494), "141 vB at 3.5 sat/vB, rounded up")
        XCTAssertEqual(WalletSendConfirmPresenter.formatFeeRate(3.5, locale: Locale(identifier: "en_US")), "3.5 sat/vB")
        XCTAssertEqual(WalletSendConfirmPresenter.formatFeeRate(2, locale: Locale(identifier: "en_US")), "2 sat/vB")
        XCTAssertEqual(WalletSendConfirmPresenter.formatFeeRate(1.25, locale: Locale(identifier: "de_DE")), "1,25 sat/vB")
        XCTAssertEqual(WalletSendConfirmPresenter.formatFeeRate(48.7, locale: Locale(identifier: "en_US")), "49 sat/vB")
    }

    // MARK: - Helpers

    private func accountInfo() async throws -> AccountInfo {
        // Each read is a fresh scan, as after the 2-minute cache expires.
        await BitcoinWalletBalanceCache.shared.invalidate(
            BitcoinWalletBalanceCache.Key(
                walletId: wallet.metaId,
                network: .mainnet,
                baseURL: BitcoinIndexerNetwork.mainnet.defaultBaseURL.absoluteString,
                gapLimit: UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit,
                maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
            )
        )
        let service = AccountInfoRemoteServiceDefault(
            bitcoinBalanceSync: BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: ledger)),
            bitcoinMnemonicProvider: BitcoinTestMnemonicProvider(),
            storagePerformer: EmptyStorageRequestPerformer()
        )
        let chainAsset = ChainAsset(chain: BitcoinTestWallet.chain, asset: BitcoinTestWallet.asset)
        let infos = try await service.fetchAccountInfos(for: BitcoinTestWallet.chain, wallet: wallet)
        return try XCTUnwrap(infos[chainAsset.chainAssetId] ?? nil)
    }

    private func makeTransferService() -> BitcoinTransferService {
        BitcoinTransferService(
            wallet: wallet,
            chain: BitcoinTestWallet.chain,
            client: ledger,
            mnemonicProvider: BitcoinTestMnemonicProvider(),
            sendGate: UniversalSendGate(policy: .production, remoteConfig: { .defaultConfig }),
            pendingStore: BitcoinPendingBroadcastStore(userDefaults: defaults, logger: nil),
            statusPolling: .once
        )
    }
}

private final class EmptyStorageRequestPerformer: SSFStorageQueryKit.StorageRequestPerformer {
    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        chain _: ChainModel
    ) async throws -> T? { nil }

    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<T>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func perform(
        _: [any MixStorageRequest],
        chain _: ChainModel
    ) async throws -> [MixStorageResponse] { [] }
}

private final class FeeRateListenerSpy: BitcoinTransferFeeRateListener {
    var onFee: (() -> Void)?
    private(set) var fee: BigUInt?
    private(set) var rate: Double?

    func didReceiveBitcoinFee(fee: BigUInt, feeRateSatPerVbyte: Double) {
        self.fee = fee
        rate = feeRateSatPerVbyte
        onFee?()
    }

    func didReceiveFee(fee: BigUInt) {
        self.fee = fee
        onFee?()
    }

    func didReceiveFeeError(feeError _: Error) {
        onFee?()
    }
}
