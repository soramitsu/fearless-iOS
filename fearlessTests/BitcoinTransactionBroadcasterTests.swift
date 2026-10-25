import XCTest
@testable import fearless

final class BitcoinTransactionBroadcasterTests: XCTestCase {
    func testNormalizesTransactionHexDelegatesSelectedNetworkAndValidatesTxidResponse() async throws {
        let client = FakeBitcoinIndexerClient(broadcastResponse: Self.txid.uppercased())
        let broadcaster = BitcoinTransactionBroadcaster(client: client)

        let result = try await broadcaster.broadcast(
            txHex: "  00AA  ",
            network: .testnet,
            baseURL: "https://bitcoin.example/api"
        )

        XCTAssertEqual(result.network, .testnet)
        XCTAssertEqual(result.txHex, "00aa")
        XCTAssertEqual(result.txid, Self.txid)
        XCTAssertEqual(client.lastTxHex, "00aa")
        XCTAssertEqual(client.lastNetwork, .testnet)
        XCTAssertEqual(client.lastBaseURL, "https://bitcoin.example/api")
    }

    func testRejectsInvalidTransactionHexBeforeCallingIndexer() async {
        let client = FakeBitcoinIndexerClient(broadcastResponse: Self.txid)
        let broadcaster = BitcoinTransactionBroadcaster(client: client)

        await assertBroadcastError(.invalidTxHex) {
            _ = try await broadcaster.broadcast(txHex: "00gg")
        }
        XCTAssertNil(client.lastTxHex)
    }

    func testRejectsMalformedTxidReturnedByIndexer() async {
        let broadcaster = BitcoinTransactionBroadcaster(
            client: FakeBitcoinIndexerClient(broadcastResponse: "not-a-txid")
        )

        await assertBroadcastError(.invalidTxidResponse) {
            _ = try await broadcaster.broadcast(txHex: "00aa")
        }
    }

    private func assertBroadcastError(
        _ expected: BitcoinBroadcastError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected Bitcoin broadcast error \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BitcoinBroadcastError, expected, file: file, line: line)
        }
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let broadcastResponse: String
        private(set) var lastTxHex: String?
        private(set) var lastNetwork: BitcoinIndexerNetwork?
        private(set) var lastBaseURL: String?

        init(broadcastResponse: String) {
            self.broadcastResponse = broadcastResponse
        }

        func address(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> BitcoinEsploraAddress {
            fatalError("Not used")
        }

        func utxos(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [BitcoinEsploraUtxo] {
            fatalError("Not used")
        }

        func transactions(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?,
            lastSeenTxid: String?,
            mempool: Bool
        ) async throws -> [BitcoinEsploraTransaction] {
            fatalError("Not used")
        }

        func feeEstimates(
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [String: Double] {
            fatalError("Not used")
        }

        func broadcastTransaction(
            txHex: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> String {
            lastTxHex = txHex
            lastNetwork = network
            lastBaseURL = baseURL

            return broadcastResponse
        }
    }

    private static let txid = String(repeating: "11", count: 32)
}
