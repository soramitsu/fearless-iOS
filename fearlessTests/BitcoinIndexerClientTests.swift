import XCTest
@testable import fearless

final class BitcoinIndexerClientTests: XCTestCase {
    func testDelegatesEsploraReadEndpointsThroughValidatedRoutes() async throws {
        let transport = FakeBitcoinIndexerTransport()
        let client = BitcoinIndexerClient(transport: transport)

        transport.enqueue(Self.addressJSON)
        _ = try await client.address(address: Self.mainnetAddress)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://blockstream.info/api/address/\(Self.mainnetAddress)"
        )
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")

        transport.enqueue(Self.utxosJSON)
        _ = try await client.utxos(address: Self.testnetAddress, network: .testnet)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://blockstream.info/testnet/api/address/\(Self.testnetAddress)/utxo"
        )

        transport.enqueue(Self.transactionsJSON)
        _ = try await client.transactions(address: Self.mainnetAddress, lastSeenTxid: Self.txid.uppercased())
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://blockstream.info/api/address/\(Self.mainnetAddress)/txs/chain/\(Self.txid)"
        )

        transport.enqueue(Self.transactionsJSON)
        _ = try await client.transactions(address: Self.mainnetAddress, mempool: true)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://blockstream.info/api/address/\(Self.mainnetAddress)/txs/mempool"
        )
    }

    func testDelegatesBroadcastWithNormalizedTextTransactionBody() async throws {
        let transport = FakeBitcoinIndexerTransport()
        let client = BitcoinIndexerClient(transport: transport)

        transport.enqueue(Data(Self.txid.utf8))
        _ = try await client.broadcastTransaction(txHex: "  00AA  ", network: .testnet)

        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://blockstream.info/testnet/api/tx")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "text/plain")
        XCTAssertEqual(transport.lastRequest?.httpBody, Data("00aa".utf8))

        do {
            _ = try await client.broadcastTransaction(txHex: "00gg")
            XCTFail("Expected invalid Bitcoin tx hex to be rejected")
        } catch {
            XCTAssertEqual(error as? BitcoinIndexerRouteError, .invalidTxHex)
        }
    }

    private final class FakeBitcoinIndexerTransport: UniversalWalletHTTPTransport {
        private var queuedResponses: [Data] = []
        private(set) var lastRequest: URLRequest?

        func enqueue(_ data: Data) {
            queuedResponses.append(data)
        }

        func perform(_ request: URLRequest) async throws -> Data {
            lastRequest = request
            return queuedResponses.isEmpty ? Data("{}".utf8) : queuedResponses.removeFirst()
        }
    }

    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let testnetAddress = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"
    private static let txid = String(repeating: "11", count: 32)

    private static let addressJSON = Data("""
    {
      "address": "\(mainnetAddress)",
      "chain_stats": {
        "funded_txo_count": 0,
        "funded_txo_sum": 0,
        "spent_txo_count": 0,
        "spent_txo_sum": 0,
        "tx_count": 0
      },
      "mempool_stats": {
        "funded_txo_count": 0,
        "funded_txo_sum": 0,
        "spent_txo_count": 0,
        "spent_txo_sum": 0,
        "tx_count": 0
      }
    }
    """.utf8)

    private static let utxosJSON = Data("""
    [
      {
        "txid": "\(txid)",
        "vout": 0,
        "value": 1,
        "status": {
          "confirmed": true
        }
      }
    ]
    """.utf8)

    private static let transactionsJSON = Data("""
    [
      {
        "txid": "\(txid)",
        "status": {
          "confirmed": true
        }
      }
    ]
    """.utf8)
}
