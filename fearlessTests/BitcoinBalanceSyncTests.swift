import XCTest
@testable import fearless

final class BitcoinBalanceSyncTests: XCTestCase {
    func testSumsConfirmedAndMempoolBalancesFromDiscoveredReceiveAddresses() async throws {
        let balances = try Self.balancesByAddress([
            0: AddressBalance(confirmedSats: 10, mempoolSats: 2),
            1: AddressBalance(confirmedSats: 3, mempoolSats: 5)
        ])
        let client = FakeBitcoinIndexerClient(balances: balances)
        let balanceSync = BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: client))

        let result = try await balanceSync.balance(
            mnemonic: Self.mnemonic,
            gapLimit: 2,
            maxLookahead: 5
        )

        XCTAssertEqual(result.confirmedSats, 13)
        XCTAssertEqual(result.mempoolSats, 7)
        XCTAssertEqual(result.totalSats, 20)
        XCTAssertEqual(result.usedAddresses.map(\.index), [0, 1])
        XCTAssertEqual(client.addressCalls.count, 6)
    }

    func testIncludesFundsDiscoveredOnBip84ChangeBranch() async throws {
        let receiveAddress = try Self.address(index: 0, change: 0)
        let changeAddress = try Self.address(index: 0, change: 1)
        let client = FakeBitcoinIndexerClient(balances: [
            receiveAddress: AddressBalance(confirmedSats: 10, mempoolSats: 0),
            changeAddress: AddressBalance(confirmedSats: 25, mempoolSats: 2)
        ])
        let balanceSync = BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: client))

        let result = try await balanceSync.balance(
            mnemonic: Self.mnemonic,
            gapLimit: 1,
            maxLookahead: 4
        )

        XCTAssertEqual(result.confirmedSats, 35)
        XCTAssertEqual(result.mempoolSats, 2)
        XCTAssertEqual(Set(result.usedAddresses.map(\.path)), Set([
            try BitcoinKeyDerivation.getReceivePath(index: 0, change: 0),
            try BitcoinKeyDerivation.getReceivePath(index: 0, change: 1)
        ]))
    }

    func testRejectsBalanceOverflowAcrossDiscoveredAddresses() async throws {
        let balances = try Self.balancesByAddress([
            0: AddressBalance(confirmedSats: Int64.max, mempoolSats: 0),
            1: AddressBalance(confirmedSats: Int64.max, mempoolSats: 0)
        ])
        let client = FakeBitcoinIndexerClient(balances: balances)
        let balanceSync = BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: client))

        do {
            _ = try await balanceSync.balance(
                mnemonic: Self.mnemonic,
                gapLimit: 1,
                maxLookahead: 4
            )
            XCTFail("Expected Bitcoin balance overflow to be rejected")
        } catch {
            XCTAssertEqual(error as? BitcoinBalanceSyncError, .balanceOverflow)
        }
    }

    func testAllowsNegativeMempoolDeltaForPendingOutgoingTransactions() async throws {
        let balances = try Self.balancesByAddress([
            0: AddressBalance(confirmedSats: 100_000, mempoolSats: -25_000)
        ])
        let client = FakeBitcoinIndexerClient(balances: balances)
        let balanceSync = BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: client))

        let result = try await balanceSync.balance(
            mnemonic: Self.mnemonic,
            gapLimit: 1,
            maxLookahead: 4
        )

        XCTAssertEqual(result.confirmedSats, 100_000)
        XCTAssertEqual(result.mempoolSats, -25_000)
        XCTAssertEqual(result.totalSats, 75_000)
        XCTAssertEqual(result.usedAddresses.map(\.index), [0])
    }

    func testRejectsNegativeTotalAddressBalance() async throws {
        let balances = try Self.balancesByAddress([
            0: AddressBalance(confirmedSats: 10_000, mempoolSats: -25_000)
        ])
        let client = FakeBitcoinIndexerClient(balances: balances)
        let balanceSync = BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: client))

        do {
            _ = try await balanceSync.balance(
                mnemonic: Self.mnemonic,
                gapLimit: 1,
                maxLookahead: 4
            )
            XCTFail("Expected negative total address balance to be rejected")
        } catch {
            XCTAssertEqual(error as? BitcoinBalanceSyncError, .invalidAddressBalance)
        }
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let balances: [String: AddressBalance]
        private(set) var addressCalls: [String] = []
        private(set) var utxoCalls: [String] = []

        init(balances: [String: AddressBalance]) {
            self.balances = balances
        }

        func address(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> BitcoinEsploraAddress {
            addressCalls.append(address)
            let balance = balances[address] ?? AddressBalance()

            return BitcoinBalanceSyncTests.addressStats(
                address: address,
                confirmedSats: balance.confirmedSats,
                mempoolSats: balance.mempoolSats,
                txCount: balance.confirmedSats > 0 || balance.mempoolSats > 0 ? 1 : 0
            )
        }

        /// The coins behind `balances`: the confirmed balance as one confirmed coin, unless a
        /// mempool transaction spends it, in which case what is left is pending change.
        func utxos(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [BitcoinEsploraUtxo] {
            utxoCalls.append(address)
            let balance = balances[address] ?? AddressBalance()
            let pending = BitcoinEsploraTxStatus(confirmed: false, blockHash: nil, blockHeight: nil, blockTime: nil)
            let confirmed = BitcoinEsploraTxStatus(confirmed: true, blockHash: nil, blockHeight: 1, blockTime: nil)
            if balance.mempoolSats < 0 {
                let change = balance.confirmedSats + balance.mempoolSats
                return change > 0 ? [BitcoinEsploraUtxo(txid: Self.txid(2), vout: 0, value: change, status: pending)] : []
            }
            var coins: [BitcoinEsploraUtxo] = []
            if balance.confirmedSats > 0 {
                coins.append(BitcoinEsploraUtxo(txid: Self.txid(1), vout: 0, value: balance.confirmedSats, status: confirmed))
            }
            if balance.mempoolSats > 0 {
                coins.append(BitcoinEsploraUtxo(txid: Self.txid(3), vout: 0, value: balance.mempoolSats, status: pending))
            }
            return coins
        }

        private static func txid(_ seed: Int) -> String {
            String(format: "%064x", seed)
        }

        func transactions(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?,
            lastSeenTxid: String?,
            mempool: Bool
        ) async throws -> [BitcoinEsploraTransaction] {
            throw UnexpectedEndpointError()
        }

        func feeEstimates(
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [String: Double] {
            throw UnexpectedEndpointError()
        }

        func broadcastTransaction(
            txHex: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> String {
            throw UnexpectedEndpointError()
        }
    }

    private struct UnexpectedEndpointError: Error {}

    private struct AddressBalance {
        let confirmedSats: Int64
        let mempoolSats: Int64

        init(confirmedSats: Int64 = 0, mempoolSats: Int64 = 0) {
            self.confirmedSats = confirmedSats
            self.mempoolSats = mempoolSats
        }
    }

    // MARK: - Spendable balance (IOSUX-3 B2)

    func testConfirmedSpendableExcludesMempoolCoinsAndCoinsSpentInTheMempool() async throws {
        let balances = try Self.balancesByAddress([
            0: AddressBalance(confirmedSats: 10000, mempoolSats: 2000),
            1: AddressBalance(confirmedSats: 7000, mempoolSats: -7000),
            2: AddressBalance(confirmedSats: 5000, mempoolSats: -1500)
        ])
        let client = FakeBitcoinIndexerClient(balances: balances)
        let balanceSync = BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: client))

        let result = try await balanceSync.balance(mnemonic: Self.mnemonic, gapLimit: 2, maxLookahead: 6)

        XCTAssertEqual(result.totalSats, 12000 + 0 + 3500)
        // Only index 0's confirmed coin is spendable now; the rest waits for a block.
        XCTAssertEqual(result.confirmedSpendableSats, 10000)
        XCTAssertEqual(result.pendingSats, 5500)
        XCTAssertEqual(
            Set(client.utxoCalls),
            Set([try Self.address(index: 0, change: 0), try Self.address(index: 2, change: 0)]),
            "Only addresses that hold value are asked for coins"
        )
    }

    // MARK: - Rate limits (IOSUX-3 B6)

    func testRateLimitedScanBacksOffExponentiallyUpToFifteenMinutes() async throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let cache = BitcoinWalletBalanceCache(now: { clock })
        let loader = CountingLoader(error: UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: nil))

        _ = try? await cache.value(for: Self.cacheKey, loader: loader.load)
        XCTAssertEqual(loader.calls, 1)

        var delays: [TimeInterval] = []
        for _ in 0 ..< 6 {
            // Held back: no request at all until the backoff ends.
            let before = loader.calls
            var waited: TimeInterval = 0
            while loader.calls == before {
                waited += 30
                clock = clock.addingTimeInterval(30)
                _ = try? await cache.value(for: Self.cacheKey, loader: loader.load)
            }
            delays.append(waited)
        }

        XCTAssertEqual(delays, [120, 240, 480, 900, 900, 900])
    }

    func testRateLimitedScanServesTheLastScanToATransfer() async throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let cache = BitcoinWalletBalanceCache(now: { clock })
        let ok = CountingLoader(result: Self.syncResult(totalSats: 42))
        let limited = CountingLoader(error: BitcoinIndexerClientError.rateLimited(retryAfter: 300))

        _ = try await cache.value(for: Self.cacheKey, loader: ok.load)
        clock = clock.addingTimeInterval(BitcoinWalletBalanceCache.defaultMaxAge + 1)

        let stale = try await cache.value(for: Self.cacheKey, staleOnFailure: true, loader: limited.load)
        XCTAssertEqual(stale.totalSats, 42)
        do {
            _ = try await cache.value(for: Self.cacheKey, loader: limited.load)
            XCTFail("A balance refresh still reports the failure, so the list can mark it outdated")
        } catch {
            XCTAssertEqual(error as? BitcoinIndexerClientError, .rateLimited(retryAfter: 300))
        }
        XCTAssertEqual(limited.calls, 1, "The second call is held back by the service's Retry-After")
    }

    func testOfflineScanIsRetriedOnTheNextRefresh() async throws {
        let cache = BitcoinWalletBalanceCache()
        let offline = CountingLoader(error: URLError(.notConnectedToInternet))

        _ = try? await cache.value(for: Self.cacheKey, loader: offline.load)
        _ = try? await cache.value(for: Self.cacheKey, loader: offline.load)

        XCTAssertEqual(offline.calls, 2)
    }

    private static let cacheKey = BitcoinWalletBalanceCache.Key(
        walletId: "wallet",
        network: .mainnet,
        baseURL: nil,
        gapLimit: 20,
        maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
    )

    private static func syncResult(totalSats: Int64) -> BitcoinBalanceSyncResult {
        BitcoinBalanceSyncResult(
            confirmedSats: totalSats,
            mempoolSats: 0,
            totalSats: totalSats,
            usedAddresses: [],
            discovery: BitcoinReceiveDiscoveryResult(
                addresses: [],
                gapLimit: 20,
                lastUsedIndex: nil,
                nextReceiveAddress: "",
                nextReceiveIndex: 0,
                usedAddresses: []
            )
        )
    }

    private final class CountingLoader {
        private let result: Result<BitcoinBalanceSyncResult, Error>
        private(set) var calls = 0

        init(result: BitcoinBalanceSyncResult) {
            self.result = .success(result)
        }

        init(error: Error) {
            result = .failure(error)
        }

        func load() async throws -> BitcoinBalanceSyncResult {
            calls += 1
            return try result.get()
        }
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private static func balancesByAddress(_ balances: [Int: AddressBalance]) throws -> [String: AddressBalance] {
        try Dictionary(uniqueKeysWithValues: balances.map { entry in
            let address = try BitcoinKeyDerivation.deriveKey(
                mnemonic: mnemonic,
                derivationPath: BitcoinKeyDerivation.getReceivePath(index: UInt32(entry.key))
            ).address

            return (address, entry.value)
        })
    }

    private static func address(index: UInt32, change: UInt32) throws -> String {
        try BitcoinKeyDerivation.deriveKey(
            mnemonic: mnemonic,
            derivationPath: BitcoinKeyDerivation.getReceivePath(index: index, change: change)
        ).address
    }

    private static func addressStats(
        address: String,
        confirmedSats: Int64,
        mempoolSats: Int64,
        txCount: Int
    ) -> BitcoinEsploraAddress {
        BitcoinEsploraAddress(
            address: address,
            chainStats: BitcoinEsploraStats(
                fundedTxoCount: txCount,
                fundedTxoSum: confirmedSats,
                spentTxoCount: 0,
                spentTxoSum: 0,
                txCount: txCount
            ),
            mempoolStats: BitcoinEsploraStats(
                fundedTxoCount: mempoolSats > 0 ? 1 : 0,
                fundedTxoSum: max(mempoolSats, 0),
                spentTxoCount: mempoolSats < 0 ? 1 : 0,
                spentTxoSum: max(-mempoolSats, 0),
                txCount: mempoolSats == 0 ? 0 : 1
            )
        )
    }
}
