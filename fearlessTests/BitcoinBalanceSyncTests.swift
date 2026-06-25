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
        XCTAssertEqual(client.addressCalls.count, 4)
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

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let balances: [String: AddressBalance]
        private(set) var addressCalls: [String] = []

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

        func utxos(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [BitcoinEsploraUtxo] {
            throw UnexpectedEndpointError()
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
                fundedTxoSum: mempoolSats,
                spentTxoCount: 0,
                spentTxoSum: 0,
                txCount: mempoolSats > 0 ? 1 : 0
            )
        )
    }
}
