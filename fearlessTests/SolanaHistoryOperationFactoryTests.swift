import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class SolanaHistoryOperationFactoryTests: XCTestCase {
    func testAssemblyRoutesSolanaRegistryChainsToSolanaHistoryFactory() {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let repository = AnyDataProviderRepository(txStorage)

        let mainnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.solanaChain(),
            txStorage: repository
        )
        let devnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.solanaChain(chainId: UniversalWalletRegistry.solanaDevnet.chainId),
            txStorage: repository
        )
        let registryMainnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.solanaChain(chainId: UniversalWalletRegistry.solanaMainnet.id),
            txStorage: repository
        )
        let registryDevnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.solanaChain(chainId: UniversalWalletRegistry.solanaDevnet.id),
            txStorage: repository
        )

        XCTAssertTrue(mainnetFactory is SolanaHistoryOperationFactory)
        XCTAssertTrue(registryMainnetFactory is SolanaHistoryOperationFactory)
        XCTAssertTrue(devnetFactory is SolanaHistoryOperationFactory)
        XCTAssertTrue(registryDevnetFactory is SolanaHistoryOperationFactory)
    }

    func testMapsNativeSolHistoryIntoWalletTransactionPage() throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse(
                [
                    Self.transaction(signature: Self.signature1, nativeDelta: "-1005000"),
                    Self.transaction(signature: Self.signature2, nativeDelta: "750000", feeLamports: "0")
                ],
                nextBefore: Self.signature2
            )
        )

        let result = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.solAsset,
                chain: Self.solanaChain(),
                address: Self.wallet,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        let page = try XCTUnwrap(result)
        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.lastWallet, Self.wallet)
        XCTAssertEqual(client.lastBefore, nil)
        XCTAssertEqual(client.lastLimit, 10)
        XCTAssertEqual(page.context?[SolanaHistoryOperationFactory.paginationCursorKey], Self.signature2)
        XCTAssertEqual(page.transactions.count, 2)

        let outgoing = page.transactions[0]
        XCTAssertEqual(outgoing.transactionId, Self.signature1)
        XCTAssertEqual(outgoing.status, .commited)
        XCTAssertEqual(outgoing.assetId, "SOL")
        XCTAssertEqual(outgoing.amount.decimalValue, Decimal(string: "0.001005"))
        XCTAssertEqual(outgoing.fees.first?.amount.decimalValue, Decimal(string: "0.000005"))
        XCTAssertEqual(outgoing.timestamp, 1_710_000_000)
        XCTAssertEqual(outgoing.type, TransactionType.outgoing.rawValue)

        let incoming = page.transactions[1]
        XCTAssertEqual(incoming.transactionId, Self.signature2)
        XCTAssertEqual(incoming.amount.decimalValue, Decimal(string: "0.00075"))
        XCTAssertTrue(incoming.fees.isEmpty)
        XCTAssertEqual(incoming.type, TransactionType.incoming.rawValue)
    }

    func testMapsTokenHistoryIntoWalletTransactionPage() throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse(
                [
                    Self.transaction(
                        signature: Self.signature1,
                        nativeDelta: nil,
                        feeLamports: "5000",
                        tokenBalanceChanges: [
                            Self.tokenChange(mint: Self.usdcMint, amountDelta: "-1500")
                        ]
                    ),
                    Self.transaction(
                        signature: Self.signature2,
                        nativeDelta: nil,
                        tokenBalanceChanges: [
                            Self.tokenChange(mint: Self.otherTokenMint, amountDelta: "999")
                        ]
                    )
                ]
            )
        )

        let result = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.usdcAsset,
                chain: Self.solanaChain(),
                address: Self.wallet,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        let page = try XCTUnwrap(result)
        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.transactionCalls, 1)
        XCTAssertEqual(page.transactions.count, 1)

        let outgoing = page.transactions[0]
        XCTAssertEqual(outgoing.transactionId, Self.signature1)
        XCTAssertEqual(outgoing.status, .commited)
        XCTAssertEqual(outgoing.assetId, Self.usdcMint)
        XCTAssertEqual(outgoing.amount.decimalValue, Decimal(string: "0.0015"))
        XCTAssertTrue(outgoing.fees.isEmpty)
        XCTAssertEqual(outgoing.type, TransactionType.outgoing.rawValue)
    }

    func testUsesPaginationCursorAndCustomBaseURL() throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse([Self.transaction(signature: Self.signature2)])
        )

        _ = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.solAsset,
                chain: Self.solanaChain(historyBaseURL: "https://si.soramitsu.io/"),
                address: Self.wallet,
                filters: [],
                pagination: Pagination(
                    count: 25,
                    context: [SolanaHistoryOperationFactory.paginationCursorKey: Self.signature1]
                )
            )
        )

        XCTAssertEqual(client.lastBaseURL, "https://si.soramitsu.io")
        XCTAssertEqual(client.lastBefore, Self.signature1)
        XCTAssertEqual(client.lastLimit, 25)
    }

    func testRegistryIdMainnetUsesSolanaMainnetHistory() throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse([Self.transaction(signature: Self.signature1)])
        )

        let result = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.solAsset,
                chain: Self.solanaChain(chainId: UniversalWalletRegistry.solanaMainnet.id),
                address: Self.wallet,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.transactionCalls, 1)
        XCTAssertEqual(result?.transactions.first?.transactionId, Self.signature1)
    }

    func testRegistryIdDevnetUsesSolanaDevnetHistory() throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse([Self.transaction(signature: Self.signature1)])
        )

        let result = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.solAsset,
                chain: Self.solanaChain(chainId: UniversalWalletRegistry.solanaDevnet.id),
                address: Self.wallet,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.transactionCalls, 1)
        XCTAssertEqual(result?.transactions.first?.transactionId, Self.signature1)
        XCTAssertEqual(result?.transactions.first?.assetId, UniversalWalletRegistry.solanaDevnet.nativeAsset.id)
    }

    func testGuardPathsAvoidIndexerCalls() throws {
        let unsupportedAsset = AssetModel(
            id: "USDC",
            name: "USD Coin",
            symbol: "USDC",
            precision: 6,
            isUtility: false,
            isNative: false
        )

        for (asset, pagination, filterSet) in [
            (unsupportedAsset, Pagination(count: 10), [WalletTransactionHistoryFilter(type: .transfer, selected: true)]),
            (Self.solAsset, Pagination(count: 0), [WalletTransactionHistoryFilter(type: .transfer, selected: true)]),
            (Self.solAsset, Pagination(count: 10), [WalletTransactionHistoryFilter(type: .reward, selected: true)])
        ] {
            let client = FakeSolanaIndexerClient()
            let result = try execute(
                SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: asset,
                    chain: Self.solanaChain(),
                    address: Self.wallet,
                    filters: filterSet,
                    pagination: pagination
                )
            )

            XCTAssertEqual(client.transactionCalls, 0)
            XCTAssertEqual(result?.transactions, [])
            XCTAssertNil(result?.context)
        }
    }

    func testMalformedAddressReturnsEmptyPageBeforeNetworkCall() throws {
        let client = FakeSolanaIndexerClient()

        let result = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.solAsset,
                chain: Self.solanaChain(),
                address: "../bad",
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.transactionCalls, 0)
        XCTAssertEqual(result?.transactions, [])
        XCTAssertNil(result?.context)
    }

    func testIndexerOutageReturnsEmptyPage() throws {
        let client = FakeSolanaIndexerClient(error: TestError.indexerUnavailable)

        let result = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.solAsset,
                chain: Self.solanaChain(),
                address: Self.wallet,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.transactionCalls, 0)
        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(result?.transactions, [])
        XCTAssertNil(result?.context)
    }

    func testDropsSwapSelfAndUnknownDirectionRowsUntilWalletShapesExist() throws {
        let client = FakeSolanaIndexerClient(
            response: Self.transactionsResponse([
                Self.transaction(signature: Self.signature1, nativeDelta: "-1000", solswapRoute: "route"),
                Self.transaction(signature: Self.signature2, nativeDelta: "0")
            ])
        )

        let result = try execute(
            SolanaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.solAsset,
                chain: Self.solanaChain(),
                address: Self.wallet,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(result?.transactions, [])
    }

    private func execute(
        _ wrapper: CompoundOperationWrapper<AssetTransactionPageData?>
    ) throws -> AssetTransactionPageData? {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    private final class FakeSolanaIndexerClient: SolanaIndexerClientProtocol {
        private let response: SolanaWalletTransactionsResponse
        private let error: Error?

        private(set) var verifiedBaseURLs: [String] = []
        private(set) var verifiedExpectedChainIds: [String] = []
        private(set) var transactionCalls = 0
        private(set) var lastWallet: String?
        private(set) var lastBaseURL: String?
        private(set) var lastBefore: String?
        private(set) var lastLimit: Int?

        init(
            response: SolanaWalletTransactionsResponse = SolanaHistoryOperationFactoryTests.transactionsResponse([]),
            error: Error? = nil
        ) {
            self.response = response
            self.error = error
        }

        func serviceInfo(baseURL _: String?) async throws -> SolanaIndexerServiceInfo {
            throw TestError.unexpectedEndpoint
        }

        func verifyServiceInfo(baseURL: String?, expectedChainId: String) async throws -> SolanaIndexerServiceInfo {
            verifiedBaseURLs.append(baseURL ?? "")
            verifiedExpectedChainIds.append(expectedChainId)
            if let error {
                throw error
            }

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

        func balances(wallet _: String, baseURL _: String?) async throws -> SolanaWalletBalancesResponse {
            throw TestError.unexpectedEndpoint
        }

        func assets(wallet _: String, baseURL _: String?) async throws -> SolanaWalletAssetsResponse {
            throw TestError.unexpectedEndpoint
        }

        func state(wallet _: String, baseURL _: String?) async throws -> SolanaWalletStateResponse {
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

        func tokenMetadata(mint _: String, baseURL _: String?) async throws -> SolanaTokenMetadata {
            throw TestError.unexpectedEndpoint
        }

        func tokenMetadataBatch(mints _: [String], baseURL _: String?) async throws -> SolanaTokenMetadataBatchResponse {
            throw TestError.unexpectedEndpoint
        }
    }

    private enum TestError: Error {
        case indexerUnavailable
        case unexpectedEndpoint
    }

    private static let wallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let signature1 = String(repeating: "2", count: 88)
    private static let signature2 = String(repeating: "3", count: 88)
    private static let usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    private static let otherTokenMint = "Es9vMFrzaCERmJfrF4H2FYD4KCoNkYur5nC8LqgxmVZ1"

    private static let solAsset = AssetModel(
        id: "SOL",
        name: "Solana",
        symbol: "SOL",
        precision: 9,
        isUtility: true,
        isNative: true
    )
    private static let usdcAsset = AssetModel(
        id: usdcMint,
        name: "USD Coin",
        symbol: "USDC",
        precision: 6,
        isUtility: false,
        isNative: false
    )

    private static func solanaChain(
        chainId: String = UniversalWalletRegistry.solanaMainnet.chainId,
        historyBaseURL: String? = nil
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://api.mainnet-beta.solana.com")!,
            name: "Solana",
            apikey: nil
        )

        let externalApi = historyBaseURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(
                    type: "subquery",
                    url: URL(string: $0)!
                ),
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: Self.isSolanaDevnet(chainId) ? "Solana Devnet" : "Solana",
            assets: [solAsset],
            xcm: nil,
            nodes: [node],
            addressPrefix: 0,
            icon: nil,
            options: Self.isSolanaDevnet(chainId) ? [.testnet] : nil,
            externalApi: externalApi,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private static func isSolanaDevnet(_ chainId: String) -> Bool {
        [
            UniversalWalletRegistry.solanaDevnet.chainId,
            UniversalWalletRegistry.solanaDevnet.id
        ].contains(chainId)
    }

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
        signature: String,
        status: String = "success",
        nativeDelta: String? = "-1000",
        feeLamports: String? = "5000",
        tokenBalanceChanges: [SolanaTokenBalanceChange] = [],
        solswapRoute: String? = nil
    ) -> SolanaWalletTransactionRecord {
        SolanaWalletTransactionRecord(
            signature: signature,
            slot: 100,
            timestamp: 1_710_000_000,
            status: status,
            feeLamports: feeLamports,
            nativeBalanceChangeLamports: nativeDelta,
            tokenBalanceChanges: tokenBalanceChanges,
            programIds: [],
            solswapRoute: solswapRoute
        )
    }

    private static func tokenChange(
        mint: String = usdcMint,
        amountDelta: String = "-1500",
        decimals: Int = 6
    ) -> SolanaTokenBalanceChange {
        SolanaTokenBalanceChange(
            mint: mint,
            preAmount: "2000",
            postAmount: "500",
            amountDelta: amountDelta,
            decimals: decimals,
            uiAmountDeltaString: "-0.0015"
        )
    }
}
