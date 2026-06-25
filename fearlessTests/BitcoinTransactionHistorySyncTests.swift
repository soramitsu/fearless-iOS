import XCTest
@testable import fearless

final class BitcoinTransactionHistorySyncTests: XCTestCase {
    func testNormalizesOutgoingAndIncomingTransactionsFromEsplora() async throws {
        let client = FakeBitcoinIndexerClient(
            transactions: [
                Self.transaction(
                    txid: Self.txid1,
                    fee: 141,
                    status: BitcoinEsploraTxStatus(
                        confirmed: true,
                        blockHash: Self.blockHash,
                        blockHeight: 100,
                        blockTime: 1_710_000_000
                    ),
                    vin: [Self.input(Self.mainnetAddress, 100_000)],
                    vout: [Self.output(Self.counterparty, 60_000), Self.output(Self.mainnetAddress, 39_859)]
                ),
                Self.transaction(
                    txid: Self.txid2,
                    fee: 200,
                    status: BitcoinEsploraTxStatus(confirmed: false, blockHash: nil, blockHeight: nil, blockTime: nil),
                    vin: [Self.input(Self.counterparty, 75_200)],
                    vout: [Self.output(Self.mainnetAddress, 75_000)]
                ),
                Self.transaction(
                    txid: Self.txid3,
                    vin: [Self.input(Self.counterparty, 10_000)],
                    vout: [Self.output(Self.counterparty, 9_900)]
                )
            ]
        )

        let history = try await BitcoinTransactionHistorySync(client: client).history(
            address: Self.mainnetAddress,
            baseURL: "https://bitcoin.example/api",
            lastSeenTxid: Self.txid0.uppercased()
        )

        XCTAssertEqual(history.address, Self.mainnetAddress)
        XCTAssertEqual(history.network, .mainnet)
        XCTAssertEqual(history.nextLastSeenTxid, Self.txid3)
        XCTAssertEqual(client.lastAddress, Self.mainnetAddress)
        XCTAssertEqual(client.lastBaseURL, "https://bitcoin.example/api")
        XCTAssertEqual(client.lastSeenTxid, Self.txid0.uppercased())
        XCTAssertEqual(history.entries.count, 2)

        let outgoing = history.entries[0]
        XCTAssertEqual(outgoing.txid, Self.txid1)
        XCTAssertEqual(outgoing.blockHash, Self.blockHash)
        XCTAssertEqual(outgoing.blockHeight, 100)
        XCTAssertEqual(outgoing.timestamp, 1_710_000_000)
        XCTAssertEqual(outgoing.amountSats, 60_000)
        XCTAssertEqual(outgoing.feeSats, 141)
        XCTAssertEqual(outgoing.from, Self.mainnetAddress)
        XCTAssertEqual(outgoing.to, Self.counterparty)
        XCTAssertTrue(outgoing.outgoing)
        XCTAssertTrue(outgoing.confirmed)

        let incoming = history.entries[1]
        XCTAssertEqual(incoming.txid, Self.txid2)
        XCTAssertEqual(incoming.blockHash, Self.txid2)
        XCTAssertEqual(incoming.amountSats, 75_000)
        XCTAssertEqual(incoming.feeSats, 0)
        XCTAssertEqual(incoming.from, Self.counterparty)
        XCTAssertEqual(incoming.to, Self.mainnetAddress)
        XCTAssertFalse(incoming.outgoing)
        XCTAssertFalse(incoming.confirmed)
    }

    func testFiltersMalformedNoMovementAndNonPositiveAmountTransactions() async throws {
        let client = FakeBitcoinIndexerClient(
            transactions: [
                Self.transaction(
                    txid: Self.txid1,
                    vin: [BitcoinEsploraTransactionInput(prevout: BitcoinEsploraTransactionOutput(scriptPubKeyAddress: Self.mainnetAddress, value: nil))],
                    vout: [Self.output(Self.mainnetAddress, 900)]
                ),
                Self.transaction(
                    txid: Self.txid2,
                    fee: 141,
                    vin: [Self.input(Self.mainnetAddress, 1_000)],
                    vout: [Self.output(Self.mainnetAddress, 859)]
                ),
                Self.transaction(
                    txid: "not-a-txid",
                    vin: [Self.input(Self.counterparty, 2_000)],
                    vout: [Self.output(Self.mainnetAddress, 1_000)]
                )
            ]
        )

        let history = try await BitcoinTransactionHistorySync(client: client).history(address: Self.mainnetAddress)

        XCTAssertEqual(history.entries.count, 0)
        XCTAssertEqual(history.nextLastSeenTxid, Self.txid2)
    }

    func testRejectsWrongNetworkAddressBeforeFetchingHistory() async {
        let client = FakeBitcoinIndexerClient(transactions: [])

        do {
            _ = try await BitcoinTransactionHistorySync(client: client).history(address: Self.testnetAddress)
            XCTFail("Expected wrong-network Bitcoin address to be rejected")
        } catch {
            XCTAssertEqual(error as? BitcoinTransactionHistoryError, .invalidAddress)
            XCTAssertEqual(client.calls, 0)
        }

        let windowClient = FakeBitcoinIndexerClient()
        do {
            _ = try await BitcoinTransactionHistorySync(client: windowClient).historyWindow(address: Self.testnetAddress)
            XCTFail("Expected wrong-network Bitcoin address to be rejected")
        } catch {
            XCTAssertEqual(error as? BitcoinTransactionHistoryError, .invalidAddress)
            XCTAssertEqual(windowClient.calls, 0)
        }
    }

    func testHistoryWindowFollowsEsploraChainPagesUntilShortPage() async throws {
        let transactions = (1...27).map { Self.outgoingTransaction(txid: Self.txid(at: $0)) }
        let pageOneCursor = transactions[24].txid
        let client = FakeBitcoinIndexerClient(
            transactionProvider: { cursor in
                if cursor == nil {
                    return Array(transactions.prefix(25))
                }
                if cursor == pageOneCursor {
                    return Array(transactions.dropFirst(25))
                }

                return []
            }
        )

        let history = try await BitcoinTransactionHistorySync(client: client).historyWindow(
            address: Self.mainnetAddress,
            baseURL: "https://bitcoin.example/api"
        )

        XCTAssertEqual(client.calls, 2)
        XCTAssertEqual(client.lastSeenTxids, [nil, pageOneCursor])
        XCTAssertEqual(history.entries.count, 27)
        XCTAssertEqual(history.nextLastSeenTxid, transactions.last?.txid)
    }

    func testHistoryWindowStopsWhenPageRepeatsSameCursorAndEntries() async throws {
        let transactions = (1...25).map { Self.outgoingTransaction(txid: Self.txid(at: $0)) }
        let repeatedCursor = transactions.last?.txid
        let client = FakeBitcoinIndexerClient(
            transactionProvider: { cursor in
                if cursor == nil {
                    return transactions
                }
                if cursor == repeatedCursor {
                    return transactions
                }

                return []
            }
        )

        let history = try await BitcoinTransactionHistorySync(client: client).historyWindow(address: Self.mainnetAddress)

        XCTAssertEqual(client.calls, 2)
        XCTAssertEqual(client.lastSeenTxids, [nil, repeatedCursor])
        XCTAssertEqual(history.entries.count, 25)
        XCTAssertEqual(history.nextLastSeenTxid, repeatedCursor)
    }

    func testHistoryWindowCapsPaginationBeforeUnboundedEsploraTraversal() async throws {
        let transactions = (1...325).map { Self.outgoingTransaction(txid: Self.txid(at: $0)) }
        let client = FakeBitcoinIndexerClient(
            transactionProvider: { cursor in
                let startIndex = cursor.flatMap { previous in
                    transactions.firstIndex { $0.txid == previous }.map { $0 + 1 }
                } ?? 0

                return Array(transactions.dropFirst(startIndex).prefix(25))
            }
        )

        let history = try await BitcoinTransactionHistorySync(client: client).historyWindow(address: Self.mainnetAddress)

        XCTAssertEqual(client.calls, 12)
        XCTAssertEqual(history.entries.count, 300)
        XCTAssertEqual(history.nextLastSeenTxid, transactions[299].txid)
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let transactionsResponse: [BitcoinEsploraTransaction]
        private let transactionProvider: ((String?) -> [BitcoinEsploraTransaction])?
        private(set) var calls = 0
        private(set) var lastAddress: String?
        private(set) var lastBaseURL: String?
        private(set) var lastSeenTxid: String?
        private(set) var lastSeenTxids: [String?] = []

        init(
            transactions: [BitcoinEsploraTransaction] = [],
            transactionProvider: ((String?) -> [BitcoinEsploraTransaction])? = nil
        ) {
            transactionsResponse = transactions
            self.transactionProvider = transactionProvider
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
            return []
        }

        func transactions(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?,
            lastSeenTxid: String?,
            mempool: Bool
        ) async throws -> [BitcoinEsploraTransaction] {
            calls += 1
            lastAddress = address
            lastBaseURL = baseURL
            self.lastSeenTxid = lastSeenTxid
            lastSeenTxids.append(lastSeenTxid)

            return transactionProvider?(lastSeenTxid) ?? transactionsResponse
        }

        func feeEstimates(
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [String: Double] {
            return [:]
        }

        func broadcastTransaction(
            txHex: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> String {
            return BitcoinTransactionHistorySyncTests.txid1
        }
    }

    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let testnetAddress = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"
    private static let counterparty = "bc1q6rz28mcfaxtmd6v789l9rrlrusdprr9pkv76kj"
    private static let blockHash = String(repeating: "aa", count: 32)
    private static let txid0 = String(repeating: "00", count: 32)
    private static let txid1 = String(repeating: "11", count: 32)
    private static let txid2 = String(repeating: "22", count: 32)
    private static let txid3 = String(repeating: "33", count: 32)

    private static func txid(at index: Int) -> String {
        let hex = String(index, radix: 16)
        return String(repeating: "0", count: 64 - hex.count) + hex
    }

    private static func outgoingTransaction(txid: String) -> BitcoinEsploraTransaction {
        transaction(
            txid: txid,
            fee: 100,
            vin: [input(mainnetAddress, 1_000)],
            vout: [output(counterparty, 800), output(mainnetAddress, 100)]
        )
    }

    private static func transaction(
        txid: String,
        fee: Int64? = nil,
        status: BitcoinEsploraTxStatus = BitcoinEsploraTxStatus(confirmed: true, blockHash: nil, blockHeight: nil, blockTime: nil),
        vin: [BitcoinEsploraTransactionInput],
        vout: [BitcoinEsploraTransactionOutput]
    ) -> BitcoinEsploraTransaction {
        BitcoinEsploraTransaction(
            txid: txid,
            status: status,
            fee: fee,
            vin: vin,
            vout: vout
        )
    }

    private static func input(_ address: String, _ value: Int64) -> BitcoinEsploraTransactionInput {
        BitcoinEsploraTransactionInput(prevout: output(address, value))
    }

    private static func output(_ address: String, _ value: Int64) -> BitcoinEsploraTransactionOutput {
        BitcoinEsploraTransactionOutput(scriptPubKeyAddress: address, value: value)
    }
}
