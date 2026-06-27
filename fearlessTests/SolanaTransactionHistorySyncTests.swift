import XCTest
@testable import fearless

final class SolanaTransactionHistorySyncTests: XCTestCase {
    func testNormalizesNativeSOLTransactionHistoryFromSI() async throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse(
                [
                    Self.transaction(signature: Self.signature1),
                    Self.transaction(signature: Self.signature2, nativeDelta: "0")
                ],
                nextBefore: Self.signature2
            )
        )

        let page = try await SolanaTransactionHistorySync(client: client).history(
            wallet: Self.wallet,
            baseURL: "https://si.soramitsu.io/",
            before: Self.signature0,
            limit: 25
        )

        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.verifiedExpectedChainIds, ["solana:mainnet"])
        XCTAssertEqual(client.lastWallet, Self.wallet)
        XCTAssertEqual(client.lastBaseURL, "https://si.soramitsu.io")
        XCTAssertEqual(client.lastBefore, Self.signature0)
        XCTAssertEqual(client.lastLimit, 25)
        XCTAssertEqual(page.pageInfo.nextCursor, Self.signature2)
        XCTAssertEqual(page.transactions.count, 1)

        let transaction = try XCTUnwrap(page.transactions.first)
        XCTAssertEqual(transaction.accountId, "solana-mainnet")
        XCTAssertEqual(transaction.chainId, "solana:mainnet")
        XCTAssertEqual(transaction.transactionId, Self.signature1)
        XCTAssertEqual(transaction.status, .confirmed)
        XCTAssertEqual(transaction.direction, .outgoing)
        XCTAssertEqual(transaction.operationType, .transfer)
        XCTAssertEqual(transaction.amount, "1005000")
        XCTAssertEqual(transaction.assetId, "SOL")
        XCTAssertEqual(transaction.feeAmount, "5000")
        XCTAssertEqual(transaction.feeAssetId, "SOL")
        XCTAssertEqual(transaction.blockNumber, "100")
        XCTAssertEqual(transaction.timestampMillis, 1_710_000_000_000)
    }

    func testAggregatesMatchingTokenDeltasAndMarksSolswapRoutesAsSwaps() async throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse([
                Self.transaction(
                    tokenChanges: [
                        Self.change(mint: Self.mint, amountDelta: "500"),
                        Self.change(mint: Self.mint, amountDelta: "-200"),
                        Self.change(mint: Self.otherMint, amountDelta: "999")
                    ],
                    solswapRoute: "batch"
                ),
                Self.transaction(
                    signature: Self.signature2,
                    tokenChanges: [Self.change(mint: Self.otherMint, amountDelta: "1")]
                )
            ])
        )

        let page = try await SolanaTransactionHistorySync(client: client).history(
            wallet: Self.wallet,
            assetId: Self.mint,
            isNative: false
        )

        let transaction = try XCTUnwrap(page.transactions.first)
        XCTAssertEqual(page.transactions.count, 1)
        XCTAssertEqual(transaction.assetId, Self.mint)
        XCTAssertEqual(transaction.amount, "300")
        XCTAssertEqual(transaction.direction, .incoming)
        XCTAssertEqual(transaction.operationType, .swap)
        XCTAssertEqual(transaction.feeAmount, "5000")
    }

    func testFiltersMalformedZeroAmountAndUnsupportedStatusTransactions() async throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse(
                [
                    Self.transaction(signature: "not-a-signature"),
                    Self.transaction(signature: Self.signature1, nativeDelta: "0"),
                    Self.transaction(signature: Self.signature2, status: "pending"),
                    Self.transaction(signature: Self.signature3, feeLamports: "-1")
                ],
                nextBefore: "not-a-signature"
            )
        )

        let page = try await SolanaTransactionHistorySync(client: client).history(wallet: Self.wallet)

        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertNil(page.pageInfo.nextCursor)
    }

    func testRejectsInvalidWalletOrAssetBeforeFetchingHistory() async {
        let client = FakeSolanaIndexerClient()

        do {
            _ = try await SolanaTransactionHistorySync(client: client).history(wallet: "../bad")
            XCTFail("Expected invalid wallet to be rejected")
        } catch {
            XCTAssertEqual(error as? SolanaTransactionHistoryError, .invalidInput)
        }

        do {
            _ = try await SolanaTransactionHistorySync(client: client).history(
                wallet: Self.wallet,
                assetId: "../bad",
                isNative: false
            )
            XCTFail("Expected invalid asset to be rejected")
        } catch {
            XCTAssertEqual(error as? SolanaTransactionHistoryError, .invalidInput)
        }

        XCTAssertEqual(client.transactionCalls, 0)
    }

    func testVerifiesDevnetHistoryAgainstDevnetServiceIdentity() async throws {
        let client = FakeSolanaIndexerClient(response: Self.transactionsResponse([]))

        let page = try await SolanaTransactionHistorySync(client: client).history(
            wallet: Self.wallet,
            network: UniversalWalletRegistry.solanaDevnet
        )

        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.verifiedExpectedChainIds, ["solana:devnet"])
        XCTAssertEqual(page.networkId, "solana-devnet")
        XCTAssertEqual(page.chainId, "solana:devnet")
    }

    private final class FakeSolanaIndexerClient: SolanaIndexerClientProtocol {
        private let response: SolanaWalletTransactionsResponse
        private(set) var verifiedBaseURLs: [String] = []
        private(set) var verifiedExpectedChainIds: [String] = []
        private(set) var transactionCalls = 0
        private(set) var lastWallet: String?
        private(set) var lastBaseURL: String?
        private(set) var lastBefore: String?
        private(set) var lastLimit: Int?

        init(response: SolanaWalletTransactionsResponse = SolanaTransactionHistorySyncTests.transactionsResponse([])) {
            self.response = response
        }

        func serviceInfo(baseURL: String?) async throws -> SolanaIndexerServiceInfo {
            throw TestError.unexpectedEndpoint
        }

        func verifyServiceInfo(baseURL: String?, expectedChainId: String) async throws -> SolanaIndexerServiceInfo {
            verifiedBaseURLs.append(baseURL ?? "")
            verifiedExpectedChainIds.append(expectedChainId)
            return SolanaIndexerServiceInfo(
                schemaVersion: 1,
                serviceId: "si.soramitsu.io",
                serviceName: "Solswap Indexer",
                ecosystem: "solana",
                chainId: expectedChainId,
                network: expectedChainId.replacingOccurrences(of: "solana:", with: ""),
                publicBaseUrl: "https://si.soramitsu.io",
                readOnly: true,
                capabilities: [],
                endpoints: [:]
            )
        }

        func balances(wallet: String, baseURL: String?) async throws -> SolanaWalletBalancesResponse {
            throw TestError.unexpectedEndpoint
        }

        func assets(wallet: String, baseURL: String?) async throws -> SolanaWalletAssetsResponse {
            throw TestError.unexpectedEndpoint
        }

        func state(wallet: String, baseURL: String?) async throws -> SolanaWalletStateResponse {
            throw TestError.unexpectedEndpoint
        }

        func transactions(
            wallet: String,
            baseURL: String?,
            before: String?,
            limit: Int
        ) async throws -> SolanaWalletTransactionsResponse {
            transactionCalls += 1
            lastWallet = wallet
            lastBaseURL = baseURL
            lastBefore = before
            lastLimit = limit
            return response
        }

        func tokenMetadata(mint: String, baseURL: String?) async throws -> SolanaTokenMetadata {
            throw TestError.unexpectedEndpoint
        }

        func tokenMetadataBatch(mints: [String], baseURL: String?) async throws -> SolanaTokenMetadataBatchResponse {
            throw TestError.unexpectedEndpoint
        }
    }

    private enum TestError: Error {
        case unexpectedEndpoint
    }

    private static let wallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let mint = "So11111111111111111111111111111111111111112"
    private static let otherMint = "5Pobwp6d9ihN9Nz38f87gVCEBFMgipFiSM2VtUhVit6w"
    private static let signature0 = String(repeating: "1", count: 88)
    private static let signature1 = String(repeating: "2", count: 88)
    private static let signature2 = String(repeating: "3", count: 88)
    private static let signature3 = String(repeating: "4", count: 88)

    private static func transactionsResponse(
        _ transactions: [SolanaWalletTransactionRecord],
        nextBefore: String? = nil
    ) -> SolanaWalletTransactionsResponse {
        SolanaWalletTransactionsResponse(
            wallet: wallet,
            before: nil,
            nextBefore: nextBefore,
            limit: 25,
            total: transactions.count,
            syncedAt: 1_710_000_000_000,
            transactions: transactions
        )
    }

    private static func transaction(
        signature: String = signature1,
        status: String = "success",
        feeLamports: String? = "5000",
        nativeDelta: String? = "-1005000",
        tokenChanges: [SolanaTokenBalanceChange] = [],
        solswapRoute: String? = nil
    ) -> SolanaWalletTransactionRecord {
        SolanaWalletTransactionRecord(
            signature: signature,
            slot: 100,
            timestamp: 1_710_000_000,
            status: status,
            feeLamports: feeLamports,
            nativeBalanceChangeLamports: nativeDelta,
            tokenBalanceChanges: tokenChanges,
            programIds: [],
            solswapRoute: solswapRoute
        )
    }

    private static func change(mint: String, amountDelta: String) -> SolanaTokenBalanceChange {
        SolanaTokenBalanceChange(
            mint: mint,
            preAmount: "0",
            postAmount: amountDelta,
            amountDelta: amountDelta,
            decimals: 6,
            uiAmountDeltaString: amountDelta
        )
    }
}
