import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class IrohaHistoryOperationFactoryTests: XCTestCase {
    func testAssemblyRoutesIrohaRegistryChainsToIrohaHistoryFactory() {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let repository = AnyDataProviderRepository(txStorage)

        for chainId in [
            UniversalWalletRegistry.taira.chainId,
            UniversalWalletRegistry.taira.id,
            UniversalWalletRegistry.nexus.chainId,
            UniversalWalletRegistry.nexus.id
        ] {
            let factory = HistoryOperationFactoriesAssembly.createOperationFactory(
                chain: Self.irohaChain(chainId: chainId),
                txStorage: repository
            )
            XCTAssertTrue(factory is IrohaHistoryOperationFactory)
        }
    }

    func testMapsTairaAccountHistoryTransferAndIgnoresLiveRawOnChainItem() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(items: [
                Self.rawOnChainItem(id: "raw-1"),
                Self.historyItem(id: "movement-1", direction: "outgoing", amount: "1.23")
            ])
        ])

        let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 10)))

        XCTAssertEqual(client.accountHistoryInvocations.count, 1)
        let invocation = try XCTUnwrap(client.accountHistoryInvocations.first)
        XCTAssertEqual(invocation.accountID, Self.tairaAddress)
        XCTAssertEqual(invocation.baseURL, "https://taira.sora.org")
        XCTAssertEqual(invocation.limit, IrohaToriiRoutes.maxLimit)
        XCTAssertEqual(invocation.offset, 0)
        XCTAssertEqual(invocation.countMode, .bounded)
        XCTAssertEqual(invocation.assetID, Self.assetId)
        XCTAssertEqual(invocation.network, UniversalWalletRegistry.taira)
        XCTAssertEqual(client.mcpCalls, 0)

        XCTAssertNil(page.context)
        XCTAssertEqual(page.transactions.count, 1)
        let transaction = page.transactions[0]
        XCTAssertEqual(transaction.transactionId, "movement-1")
        XCTAssertEqual(transaction.status, .commited)
        XCTAssertEqual(transaction.assetId, Self.assetId)
        XCTAssertEqual(transaction.peerId, Self.counterparty)
        XCTAssertEqual(transaction.amount.decimalValue, Decimal(string: "1.23"))
        XCTAssertEqual(transaction.timestamp, 1_704_067_200)
        XCTAssertEqual(transaction.type, TransactionType.outgoing.rawValue)
    }

    func testScansFullRawOnlyPageBeforeReturningLaterTransfers() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(
                items: [
                    Self.rawOnChainItem(id: "raw-1"),
                    Self.rawOnChainItem(id: "raw-2")
                ],
                hasMore: true
            ),
            Self.historyResponse(items: [
                Self.historyItem(id: "movement-1", direction: "incoming", amount: "2"),
                Self.historyItem(id: "movement-2", direction: "outgoing", amount: "3")
            ])
        ])

        let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 2)))

        XCTAssertEqual(client.accountHistoryInvocations.map(\.offset), [0, 2])
        XCTAssertEqual(page.transactions.map(\.transactionId), ["movement-1", "movement-2"])
        XCTAssertNil(page.context)
    }

    func testTairaRawOffsetContextDoesNotDropUnconsumedHistoryItems() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(
                items: [
                    Self.historyItem(id: "movement-1", direction: "outgoing", amount: "1"),
                    Self.historyItem(id: "movement-2", direction: "incoming", amount: "2")
                ],
                hasMore: false
            ),
            Self.historyResponse(items: [
                Self.historyItem(id: "movement-2", direction: "incoming", amount: "2")
            ])
        ])

        let firstPage = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 1)))
        XCTAssertEqual(firstPage.transactions.map(\.transactionId), ["movement-1"])
        XCTAssertEqual(firstPage.context?[IrohaHistoryOperationFactory.tairaRawOffsetKey], "1")

        let secondPage = try XCTUnwrap(
            execute(
                Self.tairaHistoryOperation(
                    client: client,
                    count: 1,
                    context: firstPage.context
                )
            )
        )
        XCTAssertEqual(client.accountHistoryInvocations.map(\.offset), [0, 1])
        XCTAssertEqual(secondPage.transactions.map(\.transactionId), ["movement-2"])
        XCTAssertNil(secondPage.context)
    }

    func testMapsSelfTransferAndFailedTransferWithoutMergingTransactionIds() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(items: [
                Self.historyItem(
                    id: "self-movement",
                    direction: "self",
                    amount: "0.5",
                    counterparty: nil
                ),
                Self.historyItem(
                    id: "failed-movement",
                    direction: "outgoing",
                    amount: "4",
                    status: "FAILED",
                    resultOk: false,
                    transactionHash: Self.sharedTransactionHash
                )
            ])
        ])

        let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 10)))

        XCTAssertEqual(page.transactions.count, 2)
        XCTAssertEqual(page.transactions[0].transactionId, "self-movement")
        XCTAssertEqual(page.transactions[0].peerId, Self.tairaAddress)
        XCTAssertEqual(page.transactions[0].type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(page.transactions[1].transactionId, "failed-movement")
        XCTAssertEqual(page.transactions[1].status, .rejected)
    }

    func testTairaHistoryFailsClosedForUnknownOrMalformedRows() throws {
        let invalidRows = [
            Self.rawOnChainItem(id: "raw"),
            Self.historyItem(id: "mint", type: "MINT", direction: "incoming", amount: "1"),
            Self.historyItem(
                id: "wrong-asset",
                direction: "incoming",
                amount: "1",
                assetDefinitionID: "61CtjvNd9T3THAR65GsMVHr82Bjc"
            ),
            Self.historyItem(id: "bad-scale", direction: "incoming", amount: "0.12345678901234567890123456789"),
            Self.historyItem(
                id: "decimal-rounding",
                direction: "incoming",
                amount: "999999999999.9999999999999999999999999999"
            ),
            Self.historyItem(id: "zero", direction: "incoming", amount: "0"),
            Self.historyItem(id: "unknown-direction", direction: "sideways", amount: "1"),
            Self.historyItem(id: "inconsistent", direction: "incoming", amount: "1", status: "SUCCESS", resultOk: false)
        ]
        let client = FakeIrohaToriiClient(historyResponses: [Self.historyResponse(items: invalidRows)])

        let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 10)))

        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertNil(page.context)
    }

    func testNexusMcpParsesStructuredContentAndPreservesCustomEndpoint() throws {
        let client = FakeIrohaToriiClient(
            mcpResponse: Self.mcpResponse([
                Self.instruction(
                    address: Self.nexusAddress,
                    amount: "12300000000000000000000000000"
                )
            ])
        )
        let result = try execute(
            IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.irohaAsset,
                chain: Self.irohaChain(
                    chainId: UniversalWalletRegistry.nexus.chainId,
                    historyBaseURL: "https://nexus.example"
                ),
                address: Self.nexusAddress,
                filters: [],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.mcpCalls, 1)
        XCTAssertEqual(client.lastNetwork, UniversalWalletRegistry.nexus)
        XCTAssertEqual(client.lastBaseURL, "https://nexus.example")
        XCTAssertEqual(result?.transactions.first?.amount.decimalValue, Decimal(string: "1.23"))
        XCTAssertEqual(result?.transactions.first?.type, TransactionType.outgoing.rawValue)
    }

    func testNexusMcpIsErrorReturnsEmptyPage() throws {
        let client = FakeIrohaToriiClient(mcpResponse: Self.mcpResponse([], isError: true))
        let result = try execute(
            IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.irohaAsset,
                chain: Self.irohaChain(chainId: UniversalWalletRegistry.nexus.chainId),
                address: Self.nexusAddress,
                filters: [],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.mcpCalls, 1)
        XCTAssertEqual(result?.transactions, [])
        XCTAssertNil(result?.context)
    }

    func testTairaHistoryIgnoresStalePersistedEndpointAndUsesCanonicalTorii() throws {
        let client = FakeIrohaToriiClient(historyResponses: [Self.historyResponse(items: [])])

        _ = try execute(
            Self.tairaHistoryOperation(
                client: client,
                count: 10,
                chain: Self.irohaChain(historyBaseURL: "https://stale.example")
            )
        )

        XCTAssertEqual(client.accountHistoryInvocations.first?.baseURL, "https://taira.sora.org")
    }

    func testGuardPathsAvoidToriiCalls() throws {
        let rewardFilter = [WalletTransactionHistoryFilter(type: .reward, selected: true)]

        for (pagination, filters, address) in [
            (Pagination(count: 10), rewardFilter, Self.tairaAddress),
            (Pagination(count: 0), [WalletTransactionHistoryFilter(type: .transfer, selected: true)], Self.tairaAddress),
            (Pagination(count: 10), [WalletTransactionHistoryFilter(type: .transfer, selected: true)], "../bad")
        ] {
            let client = FakeIrohaToriiClient()
            let result = try execute(
                IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: Self.irohaAsset,
                    chain: Self.irohaChain(),
                    address: address,
                    filters: filters,
                    pagination: pagination
                )
            )

            XCTAssertEqual(client.accountHistoryInvocations.count, 0)
            XCTAssertEqual(client.mcpCalls, 0)
            XCTAssertEqual(result?.transactions, [])
            XCTAssertNil(result?.context)
        }
    }

    private func execute(
        _ wrapper: CompoundOperationWrapper<AssetTransactionPageData?>
    ) throws -> AssetTransactionPageData? {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
    }

    private final class FakeIrohaToriiClient: IrohaToriiClientProtocol {
        struct AccountHistoryInvocation: Equatable {
            let accountID: String
            let baseURL: String?
            let limit: Int?
            let offset: Int64?
            let countMode: IrohaToriiCountMode?
            let assetID: String?
            let network: UniversalWalletRegistry.IrohaNetwork
        }

        private var historyResponses: [IrohaAccountHistoryResponse]
        private let mcpResponse: IrohaMcpJsonRPCResponse

        private(set) var accountHistoryInvocations: [AccountHistoryInvocation] = []
        private(set) var mcpCalls = 0
        private(set) var lastRequest: IrohaMcpJsonRPCRequest?
        private(set) var lastNetwork: UniversalWalletRegistry.IrohaNetwork?
        private(set) var lastBaseURL: String?

        init(
            historyResponses: [IrohaAccountHistoryResponse] = [],
            mcpResponse: IrohaMcpJsonRPCResponse = IrohaHistoryOperationFactoryTests.mcpResponse([])
        ) {
            self.historyResponses = historyResponses
            self.mcpResponse = mcpResponse
        }

        func health(baseURL _: String?) async throws -> Data { throw TestError.unexpectedEndpoint }

        func accounts(
            baseURL _: String?,
            limit _: Int?,
            offset _: Int64?,
            countMode _: IrohaToriiCountMode?
        ) async throws -> IrohaAccountListResponse { throw TestError.unexpectedEndpoint }

        func account(
            accountID _: String,
            baseURL _: String?,
            network _: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountListItem { throw TestError.unexpectedEndpoint }

        func accountAssets(
            accountID _: String,
            baseURL _: String?,
            limit _: Int?,
            offset _: Int64?,
            countMode _: IrohaToriiCountMode?,
            asset _: String?,
            scope _: String?,
            network _: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountAssetListResponse { throw TestError.unexpectedEndpoint }

        func accountHistory(
            accountID: String,
            baseURL: String?,
            limit: Int?,
            offset: Int64?,
            countMode: IrohaToriiCountMode?,
            assetID: String?,
            network: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountHistoryResponse {
            accountHistoryInvocations.append(
                AccountHistoryInvocation(
                    accountID: accountID,
                    baseURL: baseURL,
                    limit: limit,
                    offset: offset,
                    countMode: countMode,
                    assetID: assetID,
                    network: network
                )
            )
            guard historyResponses.isNotEmpty else { throw TestError.unexpectedEndpoint }
            return historyResponses.removeFirst()
        }

        func assetDefinitions(baseURL _: String?) async throws -> IrohaAssetDefinitionListResponse {
            throw TestError.unexpectedEndpoint
        }

        func submitTransaction(noritoBytes _: Data, baseURL _: String?) async throws -> IrohaTransactionSubmissionReceipt {
            throw TestError.unexpectedEndpoint
        }

        func transactionStatus(
            hash _: String,
            baseURL _: String?,
            scope _: IrohaTransactionStatusScope
        ) async throws -> IrohaPipelineTransactionStatusResponse { throw TestError.unexpectedEndpoint }

        func mcpCapabilities(
            network _: UniversalWalletRegistry.IrohaNetwork,
            baseURL _: String?
        ) async throws -> Data { throw TestError.unexpectedEndpoint }

        func mcpJSONRPC(
            _ request: IrohaMcpJsonRPCRequest,
            network: UniversalWalletRegistry.IrohaNetwork,
            baseURL: String?
        ) async throws -> IrohaMcpJsonRPCResponse {
            mcpCalls += 1
            lastRequest = request
            lastNetwork = network
            lastBaseURL = baseURL
            return mcpResponse
        }
    }

    private enum TestError: Error { case unexpectedEndpoint }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let assetId = UniversalWalletRegistry.tairaNativeXorAssetDefinitionId
    private static let counterparty = "i105-counterparty"
    private static let sharedTransactionHash = String(repeating: "a", count: 64)

    private static var tairaAddress: String {
        try! IrohaKeyDerivation.deriveAddress(
            mnemonic: mnemonic,
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105
    }

    private static var nexusAddress: String {
        try! IrohaKeyDerivation.deriveAddress(
            mnemonic: mnemonic,
            chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
        ).i105
    }

    private static let irohaAsset = AssetModel(
        id: assetId,
        name: "XOR",
        symbol: "XOR",
        precision: 28,
        isUtility: true,
        isNative: true
    )

    private static func tairaHistoryOperation(
        client: IrohaToriiClientProtocol,
        count: Int,
        context: PaginationContext? = nil,
        chain: ChainModel = irohaChain()
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
            asset: irohaAsset,
            chain: chain,
            address: tairaAddress,
            filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
            pagination: Pagination(count: count, context: context)
        )
    }

    private static func historyResponse(
        items: [IrohaAccountHistoryItem],
        hasMore: Bool? = false
    ) -> IrohaAccountHistoryResponse {
        IrohaAccountHistoryResponse(
            items: items,
            hasMore: hasMore,
            countMode: IrohaToriiCountMode.bounded.rawValue,
            total: nil
        )
    }

    private static func rawOnChainItem(id: String) -> IrohaAccountHistoryItem {
        IrohaAccountHistoryItem(
            id: id,
            source: "block_store",
            type: "RAW_ON_CHAIN",
            timestampMs: nil,
            status: "SUCCESS",
            resultOk: true,
            direction: "self",
            accountID: tairaAddress,
            counterpartyAccountID: nil,
            assetID: nil,
            assetDefinitionID: nil,
            amount: nil,
            transactionHash: nil,
            operationID: nil
        )
    }

    private static func historyItem(
        id: String,
        type: String = "TRANSFER",
        direction: String,
        amount: String,
        counterparty: String? = counterparty,
        status: String = "SUCCESS",
        resultOk: Bool? = true,
        assetDefinitionID: String = assetId,
        transactionHash: String = sharedTransactionHash
    ) -> IrohaAccountHistoryItem {
        IrohaAccountHistoryItem(
            id: id,
            source: "block_store",
            type: type,
            timestampMs: 1_704_067_200_000,
            status: status,
            resultOk: resultOk,
            direction: direction,
            accountID: tairaAddress,
            counterpartyAccountID: counterparty,
            assetID: "\(assetDefinitionID)#\(tairaAddress)",
            assetDefinitionID: assetDefinitionID,
            amount: amount,
            transactionHash: transactionHash,
            operationID: nil
        )
    }

    private static func irohaChain(
        chainId: String = UniversalWalletRegistry.taira.chainId,
        historyBaseURL: String? = nil
    ) -> ChainModel {
        let isNexus = UniversalWalletChainAccountSupport.chainId(
            chainId,
            matches: UniversalWalletRegistry.nexus.chainId
        )
        let defaultURL = isNexus
            ? UniversalWalletRegistry.nexus.toriiBaseURL?.absoluteString
            : UniversalWalletRegistry.taira.toriiBaseURL?.absoluteString
        let resolvedHistoryURL = historyBaseURL ?? defaultURL
        let node = ChainNodeModel(
            url: URL(string: resolvedHistoryURL ?? "https://taira.sora.org")!,
            name: isNexus ? "Nexus" : "Taira",
            apikey: nil
        )
        let externalApi = resolvedHistoryURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(type: "subquery", url: URL(string: $0)!),
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: isNexus ? "Nexus" : "Taira Testnet",
            assets: [irohaAsset],
            xcm: nil,
            nodes: [node],
            addressPrefix: 0,
            icon: nil,
            options: [.testnet],
            externalApi: externalApi,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private static func mcpResponse(
        _ instructions: [[String: IrohaJSONValue]],
        isError: Bool = false
    ) -> IrohaMcpJsonRPCResponse {
        IrohaMcpJsonRPCResponse(
            jsonrpc: "2.0",
            id: .string("history-0"),
            result: .object([
                "isError": .bool(isError),
                "structuredContent": .object([
                    "body": .object([
                        "items": .array(instructions.map { .object($0) })
                    ])
                ])
            ]),
            error: nil
        )
    }

    private static func instruction(address: String, amount: String) -> [String: IrohaJSONValue] {
        [
            "transaction_hash": .string(sharedTransactionHash),
            "created_at": .string("2024-01-01T00:00:00Z"),
            "transaction_status": .string("Committed"),
            "box": .object([
                "json": .object([
                    "payload": .object([
                        "variant": .string("Asset"),
                        "value": .object([
                            "source": .string("\(assetId)#\(address)"),
                            "destination": .string(counterparty),
                            "object": .string(amount)
                        ])
                    ])
                ])
            ])
        ]
    }
}
