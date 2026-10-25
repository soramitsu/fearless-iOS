import XCTest
@testable import fearless

final class UniversalWalletIndexerClientFactoryTests: XCTestCase {
    func testCreatesClientsOverSharedTransport() async throws {
        let transport = FakeUniversalWalletHTTPTransport()
        let factory = UniversalWalletIndexerClientFactory(transport: transport)

        transport.enqueue(Self.bitcoinAddressJSON)
        _ = try await factory.bitcoinClient().address(address: Self.bitcoinAddress)

        transport.enqueue(Self.solanaBalancesJSON)
        _ = try await factory.solanaClient().balances(wallet: Self.solanaWallet)

        XCTAssertEqual(transport.requests.map { $0.url?.host }, ["mempool.space", "si.soramitsu.io"])
    }

    private final class FakeUniversalWalletHTTPTransport: UniversalWalletHTTPTransport {
        private var queuedResponses: [Data] = []
        private(set) var requests: [URLRequest] = []

        func enqueue(_ data: Data) {
            queuedResponses.append(data)
        }

        func perform(_ request: URLRequest) async throws -> Data {
            requests.append(request)
            return queuedResponses.isEmpty ? Data("{}".utf8) : queuedResponses.removeFirst()
        }
    }

    private static let bitcoinAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let solanaWallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"

    private static let bitcoinAddressJSON = Data("""
    {
      "address": "\(bitcoinAddress)",
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

    private static let solanaBalancesJSON = Data("""
    {
      "wallet": "\(solanaWallet)",
      "native": {
        "type": "native",
        "mint": "SOL",
        "lamports": "0",
        "decimals": 9,
        "uiAmountString": "0"
      },
      "tokens": [],
      "total": 1,
      "syncedAt": 1
    }
    """.utf8)
}
