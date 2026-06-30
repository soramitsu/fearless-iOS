import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class IrohaHistoryOperationFactoryTests: XCTestCase {
    func testAssemblyRoutesIrohaRegistryChainsToIrohaHistoryFactory() {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let repository = AnyDataProviderRepository(txStorage)

        let tairaFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.irohaChain(),
            txStorage: repository
        )
        let tairaRegistryFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.irohaChain(chainId: UniversalWalletRegistry.taira.id),
            txStorage: repository
        )
        let nexusFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.irohaChain(chainId: UniversalWalletRegistry.nexus.chainId),
            txStorage: repository
        )
        let nexusRegistryFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.irohaChain(chainId: UniversalWalletRegistry.nexus.id),
            txStorage: repository
        )

        XCTAssertTrue(tairaFactory is IrohaHistoryOperationFactory)
        XCTAssertTrue(tairaRegistryFactory is IrohaHistoryOperationFactory)
        XCTAssertTrue(nexusFactory is IrohaHistoryOperationFactory)
        XCTAssertTrue(nexusRegistryFactory is IrohaHistoryOperationFactory)
    }

    func testMapsTairaToriiInstructionsIntoWalletTransactionPage() throws {
        let client = FakeIrohaToriiClient(
            response: Self.mcpResponse([
                Self.instruction(
                    value: [
                        "source": .string("\(Self.assetId)#\(Self.address)"),
                        "destination": .string(Self.counterparty),
                        "object": .string("1230000000000000000")
                    ]
                )
            ])
        )

        let result = try execute(
            IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.irohaAsset,
                chain: Self.irohaChain(),
                address: Self.address,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.mcpCalls, 1)
        XCTAssertEqual(client.lastNetwork, UniversalWalletRegistry.taira)
        XCTAssertEqual(client.lastBaseURL, UniversalWalletRegistry.taira.toriiBaseURL?.absoluteString)
        XCTAssertEqual(client.lastRequest?.method, "tools/call")
        XCTAssertEqual(client.lastRequest?.params?["name"], .string("iroha.instructions.list"))

        let arguments = try XCTUnwrap(client.lastRequest?.params?["arguments"]?.objectValue)
        XCTAssertEqual(arguments["account"], .string(Self.address))
        XCTAssertEqual(arguments["asset_id"], .string(Self.assetId))
        XCTAssertEqual(arguments["kind"], .string("Transfer"))
        XCTAssertEqual(arguments["page"], .int(0))
        XCTAssertEqual(arguments["per_page"], .int(10))
        XCTAssertEqual(arguments["transaction_status"], .string("committed"))

        let page = try XCTUnwrap(result)
        XCTAssertNil(page.context)
        XCTAssertEqual(page.transactions.count, 1)

        let transaction = page.transactions[0]
        XCTAssertEqual(transaction.transactionId, Self.txHash)
        XCTAssertEqual(transaction.status, .commited)
        XCTAssertEqual(transaction.assetId, Self.assetId)
        XCTAssertEqual(transaction.peerId, Self.counterparty)
        XCTAssertEqual(transaction.peerName, Self.counterparty)
        XCTAssertEqual(transaction.amount.decimalValue, Decimal(string: "1.23"))
        XCTAssertTrue(transaction.fees.isEmpty)
        XCTAssertEqual(transaction.timestamp, 1_704_067_200)
        XCTAssertEqual(transaction.type, TransactionType.outgoing.rawValue)
    }

    func testUsesPaginationPageAndCapsMcpPageSize() throws {
        let client = FakeIrohaToriiClient(response: Self.mcpResponse([Self.instruction()]))

        _ = try execute(
            IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.irohaAsset,
                chain: Self.irohaChain(),
                address: Self.address,
                filters: [],
                pagination: Pagination(
                    count: IrohaToriiRoutes.maxLimit + 100,
                    context: [IrohaHistoryOperationFactory.paginationPageKey: "3"]
                )
            )
        )

        let arguments = try XCTUnwrap(client.lastRequest?.params?["arguments"]?.objectValue)
        XCTAssertEqual(arguments["page"], .int(3))
        XCTAssertEqual(arguments["per_page"], .int(Int64(IrohaToriiRoutes.maxLimit)))
    }

    func testGuardPathsAvoidToriiCalls() throws {
        let rewardFilter = [WalletTransactionHistoryFilter(type: .reward, selected: true)]

        for (pagination, filters, address) in [
            (Pagination(count: 10), rewardFilter, Self.address),
            (Pagination(count: 0), [WalletTransactionHistoryFilter(type: .transfer, selected: true)], Self.address),
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

            XCTAssertEqual(client.mcpCalls, 0)
            XCTAssertEqual(result?.transactions, [])
            XCTAssertNil(result?.context)
        }
    }

    func testMcpErrorReturnsEmptyPage() throws {
        let client = FakeIrohaToriiClient(
            response: IrohaMcpJsonRPCResponse(
                jsonrpc: "2.0",
                id: .string("history-0"),
                result: nil,
                error: IrohaMcpJsonRPCError(code: -32000, message: "index unavailable", data: nil)
            )
        )

        let result = try execute(
            IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.irohaAsset,
                chain: Self.irohaChain(),
                address: Self.address,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.mcpCalls, 1)
        XCTAssertEqual(result?.transactions, [])
        XCTAssertNil(result?.context)
    }

    private func execute(
        _ wrapper: CompoundOperationWrapper<AssetTransactionPageData?>
    ) throws -> AssetTransactionPageData? {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    private final class FakeIrohaToriiClient: IrohaToriiClientProtocol {
        private let response: IrohaMcpJsonRPCResponse

        private(set) var mcpCalls = 0
        private(set) var lastRequest: IrohaMcpJsonRPCRequest?
        private(set) var lastNetwork: UniversalWalletRegistry.IrohaNetwork?
        private(set) var lastBaseURL: String?

        init(response: IrohaMcpJsonRPCResponse = IrohaHistoryOperationFactoryTests.mcpResponse([])) {
            self.response = response
        }

        func health(baseURL _: String?) async throws -> Data {
            throw TestError.unexpectedEndpoint
        }

        func accounts(
            baseURL _: String?,
            limit _: Int?,
            offset _: Int64?,
            countMode _: IrohaToriiCountMode?
        ) async throws -> IrohaAccountListResponse {
            throw TestError.unexpectedEndpoint
        }

        func account(
            accountID _: String,
            baseURL _: String?,
            network _: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountListItem {
            throw TestError.unexpectedEndpoint
        }

        func accountAssets(
            accountID _: String,
            baseURL _: String?,
            limit _: Int?,
            offset _: Int64?,
            countMode _: IrohaToriiCountMode?,
            asset _: String?,
            scope _: String?,
            network _: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountAssetListResponse {
            throw TestError.unexpectedEndpoint
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
        ) async throws -> IrohaPipelineTransactionStatusResponse {
            throw TestError.unexpectedEndpoint
        }

        func mcpCapabilities(
            network _: UniversalWalletRegistry.IrohaNetwork,
            baseURL _: String?
        ) async throws -> Data {
            throw TestError.unexpectedEndpoint
        }

        func mcpJSONRPC(
            _ request: IrohaMcpJsonRPCRequest,
            network: UniversalWalletRegistry.IrohaNetwork,
            baseURL: String?
        ) async throws -> IrohaMcpJsonRPCResponse {
            mcpCalls += 1
            lastRequest = request
            lastNetwork = network
            lastBaseURL = baseURL

            return response
        }
    }

    private enum TestError: Error {
        case unexpectedEndpoint
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let assetId = "xor#sora"
    private static let txHash = String(repeating: "aa", count: 32)
    private static let counterparty = "i105counterparty"
    private static var address: String {
        try! IrohaKeyDerivation.deriveAddress(
            mnemonic: mnemonic,
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105
    }

    private static let irohaAsset = AssetModel(
        id: assetId,
        name: "XOR",
        symbol: "XOR",
        precision: 18,
        isUtility: true,
        isNative: true
    )

    private static func irohaChain(
        chainId: String = UniversalWalletRegistry.taira.chainId,
        historyBaseURL: String? = UniversalWalletRegistry.taira.toriiBaseURL?.absoluteString
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://taira.sora.org")!,
            name: "Taira",
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
            name: "Taira Testnet",
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

    private static func mcpResponse(_ instructions: [[String: IrohaJSONValue]]) -> IrohaMcpJsonRPCResponse {
        IrohaMcpJsonRPCResponse(
            jsonrpc: "2.0",
            id: .string("history-0"),
            result: .object([
                "body": .object([
                    "items": .array(instructions.map { .object($0) })
                ])
            ]),
            error: nil
        )
    }

    private static func instruction(value: [String: IrohaJSONValue]? = nil) -> [String: IrohaJSONValue] {
        [
            "transaction_hash": .string(txHash),
            "created_at": .string("2024-01-01T00:00:00Z"),
            "transaction_status": .string("Committed"),
            "box": .object([
                "json": .object([
                    "payload": .object([
                        "variant": .string("Asset"),
                        "value": .object(value ?? [
                            "source": .string("\(assetId)#\(address)"),
                            "destination": .string(counterparty),
                            "object": .string("1230000000000000000")
                        ])
                    ])
                ])
            ])
        ]
    }
}

private extension IrohaJSONValue {
    var objectValue: [String: IrohaJSONValue]? {
        if case let .object(value) = self {
            return value
        }

        return nil
    }
}
