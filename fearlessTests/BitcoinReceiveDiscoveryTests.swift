import XCTest
@testable import fearless

final class BitcoinReceiveDiscoveryTests: XCTestCase {
    func testScansUntilConfiguredUnusedGapAfterLastUsedAddress() async throws {
        let client = FakeBitcoinIndexerClient(usedAddresses: try Self.usedAddresses(0, 2))
        let discovery = BitcoinReceiveDiscovery(client: client)

        let result = try await discovery.discover(
            mnemonic: Self.mnemonic,
            gapLimit: 3,
            maxLookahead: 20
        )

        XCTAssertEqual(result.gapLimit, 3)
        XCTAssertEqual(result.lastUsedIndex, 2)
        XCTAssertEqual(result.nextReceiveIndex, 3)
        XCTAssertEqual(result.usedAddresses.map(\.index), [0, 2])
        XCTAssertEqual(client.addressCalls.count, 6)
    }

    func testUsesRegistryGapLimitWhenNoOverrideIsProvided() async throws {
        let client = FakeBitcoinIndexerClient()
        let discovery = BitcoinReceiveDiscovery(client: client)

        let result = try await discovery.discover(mnemonic: Self.mnemonic)

        XCTAssertEqual(result.gapLimit, UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit)
        XCTAssertEqual(client.addressCalls.count, UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit)
    }

    func testDerivesTestnetReceiveAddressesThroughTestnetIndexerNetwork() async throws {
        let client = FakeBitcoinIndexerClient()
        let discovery = BitcoinReceiveDiscovery(client: client)

        let result = try await discovery.discover(
            mnemonic: Self.mnemonic,
            network: .testnet,
            gapLimit: 1
        )

        XCTAssertTrue(try XCTUnwrap(result.addresses.first).address.hasPrefix("tb1q"))
        XCTAssertEqual(client.networkCalls, [.testnet])
    }

    func testRejectsUnsafeDiscoveryParametersBeforeIndexerCalls() async throws {
        let client = FakeBitcoinIndexerClient()
        let discovery = BitcoinReceiveDiscovery(client: client)

        try await assertDiscoveryError(.mnemonicRequired) {
            _ = try await discovery.discover(mnemonic: "", gapLimit: 2)
        }
        try await assertDiscoveryError(.invalidGapLimit) {
            _ = try await discovery.discover(mnemonic: Self.mnemonic, gapLimit: 0)
        }
        try await assertDiscoveryError(.invalidGapLimit) {
            _ = try await discovery.discover(mnemonic: Self.mnemonic, gapLimit: 101)
        }
        try await assertDiscoveryError(.invalidMaxLookahead) {
            _ = try await discovery.discover(mnemonic: Self.mnemonic, gapLimit: 5, maxLookahead: 4)
        }
        XCTAssertTrue(client.addressCalls.isEmpty)
    }

    func testFailsWhenMaxLookaheadIsExhaustedBeforeUnusedGapIsReached() async throws {
        let client = FakeBitcoinIndexerClient(usedAddresses: try Self.usedAddresses(0))
        let discovery = BitcoinReceiveDiscovery(client: client)

        try await assertDiscoveryError(.lookaheadExhausted) {
            _ = try await discovery.discover(mnemonic: Self.mnemonic, gapLimit: 3, maxLookahead: 3)
        }
    }

    func testRejectsImpossibleTransactionCountsFromIndexerResponses() async throws {
        let client = FakeBitcoinIndexerClient { address in
            Self.addressStats(address: address, chainTxCount: Int.max, mempoolTxCount: 1)
        }
        let discovery = BitcoinReceiveDiscovery(client: client)

        try await assertDiscoveryError(.invalidTransactionCount) {
            _ = try await discovery.discover(mnemonic: Self.mnemonic, gapLimit: 1)
        }
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let response: (String) -> BitcoinEsploraAddress
        private(set) var addressCalls: [String] = []
        private(set) var networkCalls: [BitcoinIndexerNetwork] = []

        init(
            usedAddresses: Set<String> = [],
            response: ((String) -> BitcoinEsploraAddress)? = nil
        ) {
            self.response = response ?? { address in
                BitcoinReceiveDiscoveryTests.addressStats(
                    address: address,
                    chainTxCount: usedAddresses.contains(address) ? 1 : 0
                )
            }
        }

        func address(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> BitcoinEsploraAddress {
            addressCalls.append(address)
            networkCalls.append(network)
            return response(address)
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

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private static func usedAddresses(_ indexes: Int...) throws -> Set<String> {
        Set(try indexes.map { index in
            try BitcoinKeyDerivation.deriveKey(
                mnemonic: mnemonic,
                derivationPath: BitcoinKeyDerivation.getReceivePath(index: UInt32(index))
            ).address
        })
    }

    private static func addressStats(
        address: String,
        chainTxCount: Int = 0,
        mempoolTxCount: Int = 0
    ) -> BitcoinEsploraAddress {
        BitcoinEsploraAddress(
            address: address,
            chainStats: BitcoinEsploraStats(
                fundedTxoCount: chainTxCount,
                fundedTxoSum: 0,
                spentTxoCount: 0,
                spentTxoSum: 0,
                txCount: chainTxCount
            ),
            mempoolStats: BitcoinEsploraStats(
                fundedTxoCount: mempoolTxCount,
                fundedTxoSum: 0,
                spentTxoCount: 0,
                spentTxoSum: 0,
                txCount: mempoolTxCount
            )
        )
    }

    private func assertDiscoveryError(
        _ expected: BitcoinReceiveDiscoveryError,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        do {
            try await operation()
            XCTFail("Expected Bitcoin discovery error \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BitcoinReceiveDiscoveryError, expected, file: file, line: line)
        }
    }
}
