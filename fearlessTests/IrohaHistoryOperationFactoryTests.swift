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
        XCTAssertEqual(invocation.limit, 10)
        XCTAssertNil(invocation.cursor)
        XCTAssertEqual(invocation.filter, Self.xorTransferFilter)
        XCTAssertEqual(invocation.network, UniversalWalletRegistry.taira)

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
                nextCursor: "cursor-1"
            ),
            Self.historyResponse(items: [
                Self.historyItem(id: "movement-1", direction: "incoming", amount: "2"),
                Self.historyItem(id: "movement-2", direction: "outgoing", amount: "3")
            ])
        ])

        let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 2)))

        XCTAssertEqual(client.accountHistoryInvocations.map(\.cursor), [nil, "cursor-1"])
        XCTAssertEqual(client.accountHistoryInvocations.map(\.limit), [2, 2])
        XCTAssertEqual(page.transactions.map(\.transactionId), ["movement-1", "movement-2"])
        XCTAssertNil(page.context)
    }

    func testContextWithoutCursorStartsFromTheNewestBlock() throws {
        let contexts: [PaginationContext?] = [
            nil,
            [:],
            ["rawOffset": "500"]
        ]
        for context in contexts {
            let client = FakeIrohaToriiClient(historyResponses: [
                Self.historyResponse(items: [
                    Self.historyItem(id: "first-transfer", direction: "incoming", amount: "1")
                ])
            ])
            let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 1, context: context)))
            XCTAssertEqual(client.accountHistoryInvocations.map(\.cursor), [nil])
            XCTAssertEqual(page.transactions.map(\.transactionId), ["first-transfer"])
        }
    }

    func testTairaCursorContextResumesAfterThePreviousPage() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(
                items: [Self.historyItem(id: "movement-1", direction: "outgoing", amount: "1")],
                nextCursor: "cursor-1"
            ),
            Self.historyResponse(items: [
                Self.historyItem(id: "movement-2", direction: "incoming", amount: "2")
            ])
        ])

        let firstPage = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 1)))
        XCTAssertEqual(firstPage.transactions.map(\.transactionId), ["movement-1"])
        XCTAssertEqual(firstPage.context, [IrohaHistoryOperationFactory.toriiCursorKey: "cursor-1"])

        let secondPage = try XCTUnwrap(
            execute(
                Self.tairaHistoryOperation(
                    client: client,
                    count: 1,
                    context: firstPage.context
                )
            )
        )
        XCTAssertEqual(client.accountHistoryInvocations.map(\.cursor), [nil, "cursor-1"])
        XCTAssertEqual(secondPage.transactions.map(\.transactionId), ["movement-2"])
        XCTAssertNil(secondPage.context)
    }

    func testTairaHistoryFollowsEmptyScanWindowsUntilItFindsTransfers() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(items: [], nextCursor: "cursor-1"),
            Self.historyResponse(items: [], nextCursor: "cursor-2"),
            Self.historyResponse(items: [], nextCursor: "cursor-3"),
            Self.historyResponse(
                items: [Self.historyItem(id: "old-transfer", direction: "incoming", amount: "7")],
                nextCursor: "cursor-4"
            )
        ])

        let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 100)))

        XCTAssertEqual(client.accountHistoryInvocations.map(\.cursor), [nil, "cursor-1", "cursor-2", "cursor-3"])
        XCTAssertEqual(page.transactions.map(\.transactionId), ["old-transfer"])
        XCTAssertEqual(page.context, [IrohaHistoryOperationFactory.toriiCursorKey: "cursor-4"])
    }

    func testTairaHistoryStopsAtTheRequestBoundAndKeepsTheCursor() throws {
        let bound = IrohaHistoryOperationFactory.maximumToriiRequestsPerPage
        let client = FakeIrohaToriiClient(historyResponses: (1 ... bound + 1).map {
            Self.historyResponse(items: [], nextCursor: "cursor-\($0)")
        })

        let page = try XCTUnwrap(execute(Self.tairaHistoryOperation(client: client, count: 100)))

        XCTAssertEqual(client.accountHistoryInvocations.count, bound)
        XCTAssertEqual(
            client.accountHistoryInvocations.map(\.cursor),
            [nil] + (1 ..< bound).map { Optional("cursor-\($0)") }
        )
        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertEqual(page.context, [IrohaHistoryOperationFactory.toriiCursorKey: "cursor-\(bound)"])
    }

    func testTairaHistoryFailsWhenTheCursorDoesNotAdvance() throws {
        let cases: [(PaginationContext?, [IrohaAccountHistoryResponse])] = [
            (nil, [
                Self.historyResponse(items: [], nextCursor: "cursor-1"),
                Self.historyResponse(items: [], nextCursor: "cursor-1")
            ]),
            ([IrohaHistoryOperationFactory.toriiCursorKey: "cursor-1"], [
                Self.historyResponse(items: [], nextCursor: "cursor-1")
            ])
        ]
        for (context, responses) in cases {
            let client = FakeIrohaToriiClient(historyResponses: responses)

            XCTAssertThrowsError(
                try execute(Self.tairaHistoryOperation(client: client, count: 10, context: context))
            )
            XCTAssertEqual(client.accountHistoryInvocations.count, responses.count)
        }
    }

    func testTairaHistoryFailsWhenAPageRepeats() throws {
        let page = [Self.rawOnChainItem(id: "raw-1"), Self.rawOnChainItem(id: "raw-2")]
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(items: page, nextCursor: "cursor-1"),
            Self.historyResponse(items: page, nextCursor: "cursor-2"),
            Self.historyResponse(items: [Self.historyItem(id: "later", direction: "incoming", amount: "1")])
        ])

        XCTAssertThrowsError(try execute(Self.tairaHistoryOperation(client: client, count: 10)))
        XCTAssertEqual(client.accountHistoryInvocations.count, 2)
    }

    func testTairaHistoryReportsToriiErrorsInsteadOfAnEmptyPage() throws {
        let client = FakeIrohaToriiClient(historyResponses: [])

        XCTAssertThrowsError(try execute(Self.tairaHistoryOperation(client: client, count: 10))) { error in
            XCTAssertEqual(error as? TestError, .unexpectedEndpoint)
        }
        XCTAssertEqual(client.accountHistoryInvocations.count, 1)
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

    func testNexusHistoryUsesToriiRESTAndPreservesCustomEndpoint() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(
                items: [
                    Self.historyItem(
                        id: "nexus-movement",
                        direction: "outgoing",
                        amount: "1.23",
                        account: Self.nexusAddress
                    )
                ],
                nextCursor: "nexus-cursor-1"
            )
        ])

        let page = try XCTUnwrap(
            execute(
                Self.nexusHistoryOperation(
                    client: client,
                    chain: Self.irohaChain(
                        chainId: UniversalWalletRegistry.nexus.chainId,
                        historyBaseURL: "https://nexus.example"
                    )
                )
            )
        )

        let invocation = try XCTUnwrap(client.accountHistoryInvocations.first)
        XCTAssertEqual(client.accountHistoryInvocations.count, 1)
        XCTAssertEqual(invocation.accountID, Self.nexusAddress)
        XCTAssertEqual(invocation.baseURL, "https://nexus.example")
        XCTAssertEqual(invocation.network, UniversalWalletRegistry.nexus)
        XCTAssertEqual(invocation.limit, 10)
        XCTAssertNil(invocation.cursor)
        XCTAssertEqual(invocation.filter, Self.xorTransferFilter)
        XCTAssertEqual(page.transactions.map(\.transactionId), ["nexus-movement"])
        XCTAssertEqual(page.transactions.first?.amount.decimalValue, Decimal(string: "1.23"))
        XCTAssertEqual(page.transactions.first?.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(page.context, [IrohaHistoryOperationFactory.toriiCursorKey: "nexus-cursor-1"])
    }

    func testNexusHistoryPagesByCursorFromItsDefaultToriiAndReportsErrors() throws {
        let client = FakeIrohaToriiClient(historyResponses: [
            Self.historyResponse(items: [], nextCursor: "nexus-cursor-2"),
            Self.historyResponse(items: [])
        ])
        let chain = Self.irohaChain(chainId: UniversalWalletRegistry.nexus.chainId)

        let page = try XCTUnwrap(
            execute(
                Self.nexusHistoryOperation(
                    client: client,
                    chain: chain,
                    context: [IrohaHistoryOperationFactory.toriiCursorKey: "nexus-cursor-1"]
                )
            )
        )
        XCTAssertEqual(client.accountHistoryInvocations.map(\.cursor), ["nexus-cursor-1", "nexus-cursor-2"])
        XCTAssertEqual(client.accountHistoryInvocations.map(\.baseURL), ["https://minamoto.sora.org", "https://minamoto.sora.org"])
        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertNil(page.context)

        XCTAssertThrowsError(try execute(Self.nexusHistoryOperation(client: client, chain: chain))) { error in
            XCTAssertEqual(error as? TestError, .unexpectedEndpoint)
        }
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
            let cursor: String?
            let filter: String?
            let network: UniversalWalletRegistry.IrohaNetwork
        }

        private var historyResponses: [IrohaAccountHistoryResponse]

        private(set) var accountHistoryInvocations: [AccountHistoryInvocation] = []

        init(historyResponses: [IrohaAccountHistoryResponse] = []) {
            self.historyResponses = historyResponses
        }

        func health(baseURL _: String?) async throws -> Data { throw TestError.unexpectedEndpoint }

        func accounts(
            baseURL _: String?,
            limit _: Int?,
            cursor _: String?
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
            cursor _: String?,
            network _: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountAssetListResponse { throw TestError.unexpectedEndpoint }

        func accountHistory(
            accountID: String,
            baseURL: String?,
            limit: Int?,
            cursor: String?,
            filter: String?,
            network: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountHistoryResponse {
            accountHistoryInvocations.append(
                AccountHistoryInvocation(
                    accountID: accountID,
                    baseURL: baseURL,
                    limit: limit,
                    cursor: cursor,
                    filter: filter,
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

    private static func nexusHistoryOperation(
        client: IrohaToriiClientProtocol,
        chain: ChainModel,
        context: PaginationContext? = nil
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
            asset: irohaAsset,
            chain: chain,
            address: nexusAddress,
            filters: [],
            pagination: Pagination(count: 10, context: context)
        )
    }

    private static let xorTransferFilter =
        #"asset_definition_id in ["6TEAJqbb8oEPmLncoNiMRbLEK6tw"] and type = "TRANSFER""#

    private static func historyResponse(
        items: [IrohaAccountHistoryItem],
        nextCursor: String? = nil
    ) -> IrohaAccountHistoryResponse {
        IrohaAccountHistoryResponse(items: items, nextCursor: nextCursor)
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
        transactionHash: String = sharedTransactionHash,
        account: String = tairaAddress
    ) -> IrohaAccountHistoryItem {
        IrohaAccountHistoryItem(
            id: id,
            source: "block_store",
            type: type,
            timestampMs: 1_704_067_200_000,
            status: status,
            resultOk: resultOk,
            direction: direction,
            accountID: account,
            counterpartyAccountID: counterparty,
            assetID: "\(assetDefinitionID)#\(account)",
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
}
