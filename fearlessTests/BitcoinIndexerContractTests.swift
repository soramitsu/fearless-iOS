import XCTest
@testable import fearless

final class BitcoinIndexerContractTests: XCTestCase {
    func testBuildsBitcoinEsploraEndpointURLsWithValidatedParameters() throws {
        XCTAssertEqual(
            try BitcoinIndexerRoutes.addressURL(address: Self.mainnetAddress).absoluteString,
            "\(UniversalWalletRegistry.bitcoinMainnetIndexerBaseURL.absoluteString)/address/\(Self.mainnetAddress)"
        )
        XCTAssertEqual(
            try BitcoinIndexerRoutes.utxosURL(address: Self.testnetAddress, network: .testnet).absoluteString,
            "https://mempool.space/testnet/api/address/\(Self.testnetAddress)/utxo"
        )
        XCTAssertEqual(
            try BitcoinIndexerRoutes.transactionsURL(
                address: Self.mainnetAddress,
                baseURL: "https://bitcoin.example/api/"
            ).absoluteString,
            "https://bitcoin.example/api/address/\(Self.mainnetAddress)/txs"
        )
        XCTAssertEqual(
            try BitcoinIndexerRoutes.transactionsURL(
                address: Self.mainnetAddress,
                baseURL: "https://bitcoin.example/api/",
                lastSeenTxid: Self.txid.uppercased()
            ).absoluteString,
            "https://bitcoin.example/api/address/\(Self.mainnetAddress)/txs/chain/\(Self.txid)"
        )
        XCTAssertEqual(
            try BitcoinIndexerRoutes.transactionsURL(
                address: Self.mainnetAddress,
                baseURL: "https://bitcoin.example/api/",
                mempool: true
            ).absoluteString,
            "https://bitcoin.example/api/address/\(Self.mainnetAddress)/txs/mempool"
        )
        XCTAssertEqual(
            try BitcoinIndexerRoutes.feeEstimatesURL().absoluteString,
            "https://mempool.space/api/fee-estimates"
        )
        XCTAssertEqual(
            try BitcoinIndexerRoutes.broadcastTransactionURL(network: .testnet).absoluteString,
            "https://mempool.space/testnet/api/tx"
        )
        XCTAssertEqual(try BitcoinIndexerRoutes.normalizeBroadcastTransactionBody("  00AA  "), "00aa")
    }

    func testAllowsLocalHTTPBaseURLsButRejectsNonlocalInsecureBaseURLs() throws {
        XCTAssertEqual(try BitcoinIndexerRoutes.normalizeBaseURL("http://localhost:3000/api/"), "http://localhost:3000/api")
        XCTAssertEqual(try BitcoinIndexerRoutes.normalizeBaseURL("http://127.0.0.1:3000/api/"), "http://127.0.0.1:3000/api")

        assertRouteError(.invalidBaseURL) {
            try BitcoinIndexerRoutes.normalizeBaseURL("http://blockstream.info/api")
        }
        assertRouteError(.invalidBaseURL) {
            try BitcoinIndexerRoutes.normalizeBaseURL("not a url")
        }
    }

    func testRejectsMalformedBitcoinRouteInputsBeforeNetworkCalls() {
        assertRouteError(.invalidAddress) {
            _ = try BitcoinIndexerRoutes.addressURL(address: "../bad")
        }
        assertRouteError(.invalidAddress) {
            _ = try BitcoinIndexerRoutes.addressURL(address: Self.testnetAddress, network: .mainnet)
        }
        assertRouteError(.invalidTxid) {
            _ = try BitcoinIndexerRoutes.transactionsURL(address: Self.mainnetAddress, lastSeenTxid: "../../../bad")
        }
        assertRouteError(.invalidTxHex) {
            _ = try BitcoinIndexerRoutes.normalizeBroadcastTransactionBody("abc")
        }
        assertRouteError(.invalidTxHex) {
            _ = try BitcoinIndexerRoutes.normalizeBroadcastTransactionBody("00gg")
        }
        assertRouteError(.invalidTxHex) {
            _ = try BitcoinIndexerRoutes.normalizeBroadcastTransactionBody(String(repeating: "00", count: BitcoinIndexerRoutes.maxTxHexLength / 2 + 1))
        }
    }

    func testParsesEsploraAddressStatsWithoutLosingSatoshiPrecision() throws {
        let data = """
        {
          "address": "\(Self.mainnetAddress)",
          "chain_stats": {
            "funded_txo_count": 2,
            "funded_txo_sum": 2100000000000000,
            "spent_txo_count": 1,
            "spent_txo_sum": 123456789,
            "tx_count": 3
          },
          "mempool_stats": {
            "funded_txo_count": 1,
            "funded_txo_sum": 5000,
            "spent_txo_count": 0,
            "spent_txo_sum": 0,
            "tx_count": 1
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BitcoinEsploraAddress.self, from: data)

        XCTAssertEqual(response.address, Self.mainnetAddress)
        XCTAssertEqual(response.confirmedSats, 2_099_999_876_543_211)
        XCTAssertEqual(response.mempoolSats, 5_000)
        XCTAssertEqual(response.totalSats, 2_099_999_876_548_211)
    }

    func testParsesEsploraTransactionMovementOutputsWithoutCoercingStringAmounts() throws {
        let data = """
        {
          "txid": "\(Self.txid)",
          "status": {
            "confirmed": true
          },
          "vin": [
            {
              "prevout": {
                "scriptpubkey_address": "\(Self.mainnetAddress)",
                "value": 1000
              }
            }
          ],
          "vout": [
            {
              "scriptpubkey_address": "\(Self.mainnetAddress)",
              "value": "900"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BitcoinEsploraTransaction.self, from: data)

        XCTAssertEqual(response.vin.single?.prevout?.value, 1_000)
        XCTAssertNil(response.vout.single?.value)
    }

    private func assertRouteError(
        _ expected: BitcoinIndexerRouteError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) {
        XCTAssertThrowsError(try block(), file: file, line: line) { error in
            XCTAssertEqual(error as? BitcoinIndexerRouteError, expected, file: file, line: line)
        }
    }

    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let testnetAddress = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"
    private static let txid = String(repeating: "11", count: 32)
}

private extension Array {
    var single: Element? {
        count == 1 ? first : nil
    }
}
