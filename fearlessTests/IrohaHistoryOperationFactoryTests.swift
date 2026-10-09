import BigInt
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class IrohaHistoryOperationFactoryTests: XCTestCase {
    func testAssemblyRoutesOnlyCanonicalIrohaChainIdentitiesToIrohaHistoryFactory() throws {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let repository = AnyDataProviderRepository(txStorage)

        let tairaFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.irohaChain(),
            txStorage: repository
        )
        let nexusFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.irohaChain(chainId: UniversalWalletRegistry.nexus.chainId),
            txStorage: repository
        )

        XCTAssertTrue(tairaFactory is IrohaHistoryOperationFactory)
        XCTAssertTrue(nexusFactory is IrohaHistoryOperationFactory)
        for chainId in [
            UniversalWalletRegistry.taira.id,
            UniversalWalletRegistry.taira.chainId.uppercased(),
            UniversalWalletRegistry.nexus.id,
            "unknown-iroha-chain"
        ] {
            XCTAssertFalse(
                IrohaHistoryOperationFactory.supports(chain: Self.irohaChain(chainId: chainId)),
                "Unexpected Iroha history support for \(chainId)"
            )
            XCTAssertThrowsError(
                try execute(
                    IrohaHistoryOperationFactory().fetchTransactionHistoryOperation(
                        asset: Self.irohaAsset,
                        chain: Self.irohaChain(chainId: chainId),
                        address: Self.address,
                        filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                        pagination: Pagination(count: 10)
                    )
                )
            ) { error in
                XCTAssertEqual(
                    error as? IrohaHistoryReadError,
                    .invalidNetworkIdentity(chainId)
                )
            }
        }
    }

    func testMapsTairaToriiInstructionsIntoWalletTransactionPage() throws {
        let client = FakeIrohaToriiClient(
            response: Self.mcpResponse([
                Self.instruction(
                    value: [
                        "source": .string("\(Self.assetId)#\(Self.address)"),
                        "destination": .string(Self.counterparty),
                        "object": .string("1.23")
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
        XCTAssertEqual(client.lastDefinitionsLimit, IrohaToriiRoutes.maxLimit)
        XCTAssertEqual(client.lastDefinitionsOffset, 0)
        XCTAssertEqual(client.lastDefinitionsCountMode, .bounded)
        XCTAssertEqual(client.lastRequest?.method, "tools/call")
        XCTAssertEqual(client.lastRequest?.params?["name"], .string("iroha.instructions.list"))

        let arguments = try XCTUnwrap(client.lastRequest?.params?["arguments"]?.objectValue)
        XCTAssertEqual(arguments["account"], .string(Self.address))
        XCTAssertEqual(arguments["asset_id"], .string(Self.assetId))
        XCTAssertEqual(arguments["kind"], .string("Transfer"))
        XCTAssertEqual(arguments["page"], .int(1))
        XCTAssertEqual(arguments["per_page"], .int(10))
        XCTAssertEqual(arguments["transaction_status"], .string("committed"))

        let page = try XCTUnwrap(result)
        XCTAssertNil(page.context)
        XCTAssertEqual(page.transactions.count, 1)

        let transaction = page.transactions[0]
        XCTAssertEqual(transaction.transactionId, "\(Self.txHash):0")
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
        let client = FakeIrohaToriiClient(
            response: Self.mcpResponse([Self.instruction()], page: 3, perPage: 100, totalItems: 201)
        )

        _ = try execute(
            IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.irohaAsset,
                chain: Self.irohaChain(),
                address: Self.address,
                filters: [],
                pagination: Pagination(
                    count: IrohaToriiRoutes.maxLimit + 100,
                    context: [
                        IrohaHistoryOperationFactory.paginationPageKey: "3",
                        IrohaHistoryOperationFactory.paginationTotalPagesKey: "3",
                        IrohaHistoryOperationFactory.paginationTotalItemsKey: "201"
                    ]
                )
            )
        )

        let arguments = try XCTUnwrap(client.lastRequest?.params?["arguments"]?.objectValue)
        XCTAssertEqual(arguments["page"], .int(3))
        XCTAssertEqual(arguments["per_page"], .int(Int64(IrohaHistoryOperationFactory.maxPageSize)))
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

    func testMcpErrorPropagatesAsTypedFailure() throws {
        let client = FakeIrohaToriiClient(
            response: IrohaMcpJsonRPCResponse(
                jsonrpc: "2.0",
                id: .string("history-1"),
                result: nil,
                error: IrohaMcpJsonRPCError(code: -32000, message: "index unavailable", data: nil)
            )
        )

        XCTAssertThrowsError(
            try execute(
                IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: Self.irohaAsset,
                    chain: Self.irohaChain(),
                    address: Self.address,
                    filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                    pagination: Pagination(count: 10)
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? IrohaHistoryReadError,
                .mcp(code: -32000, message: "index unavailable")
            )
        }

        XCTAssertEqual(client.mcpCalls, 1)
    }

    func testHistoryRouteWithoutFanoutEvidenceFailsClosed() throws {
        let client = FakeIrohaToriiClient(
            response: Self.mcpResponse([Self.instruction()], headers: [:])
        )

        XCTAssertThrowsError(
            try execute(
                IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: Self.irohaAsset,
                    chain: Self.irohaChain(),
                    address: Self.address,
                    filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                    pagination: Pagination(count: 10)
                )
            )
        ) { error in
            XCTAssertEqual(error as? IrohaHistoryReadError, .invalidMcpResponse("invalid_fanout_headers"))
        }
    }

    func testFlattenedLegacyMcpHistoryResultFailsClosed() throws {
        let client = FakeIrohaToriiClient(
            response: IrohaMcpJsonRPCResponse(
                jsonrpc: "2.0",
                id: .string("history-1"),
                result: .object([
                    "body": .object(["items": .array([.object(Self.instruction())])])
                ]),
                error: nil
            )
        )

        XCTAssertThrowsError(
            try execute(
                IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: Self.irohaAsset,
                    chain: Self.irohaChain(),
                    address: Self.address,
                    filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                    pagination: Pagination(count: 10)
                )
            )
        ) { error in
            XCTAssertEqual(error as? IrohaHistoryReadError, .invalidMcpResponse("invalid_tool_result"))
        }
    }

    func testMissingToriiAssetScaleFailsBeforeHistoryQuery() throws {
        let client = FakeIrohaToriiClient(definitionScale: nil)

        XCTAssertThrowsError(
            try execute(
                IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: Self.irohaAsset,
                    chain: Self.irohaChain(),
                    address: Self.address,
                    filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                    pagination: Pagination(count: 10)
                )
            )
        ) { error in
            XCTAssertEqual(error as? IrohaHistoryReadError, .missingScale(Self.assetId))
        }

        XCTAssertEqual(client.mcpCalls, 0)
    }

    func testPaddedWalletAssetDefinitionFailsBeforeHistoryQueries() throws {
        for assetId in [" \(Self.assetId)", "\(Self.assetId)\n"] {
            let client = FakeIrohaToriiClient()
            let paddedAsset = AssetModel(
                id: assetId,
                name: "XOR",
                symbol: "XOR",
                precision: 9,
                isUtility: true,
                isNative: true
            )

            XCTAssertThrowsError(
                try execute(
                    IrohaHistoryOperationFactory(client: client)
                        .fetchTransactionHistoryOperation(
                            asset: paddedAsset,
                            chain: Self.irohaChain(),
                            address: Self.address,
                            filters: [
                                WalletTransactionHistoryFilter(
                                    type: .transfer,
                                    selected: true
                                )
                            ],
                            pagination: Pagination(count: 10)
                        )
                )
            ) { error in
                XCTAssertEqual(
                    error as? IrohaHistoryReadError,
                    .nonCanonicalAssetDefinition(assetId)
                )
            }
            XCTAssertNil(client.lastDefinitionsLimit)
            XCTAssertEqual(client.mcpCalls, 0)
        }
    }

    func testNonBoundedToriiDefinitionSnapshotFailsBeforeHistoryQuery() throws {
        let client = FakeIrohaToriiClient(definitionCountMode: .exact)

        XCTAssertThrowsError(try executeHistory(client: client)) { error in
            XCTAssertEqual(error as? IrohaHistoryReadError, .truncatedDefinitions)
        }
        XCTAssertEqual(client.mcpCalls, 0)
    }

    func testLargeValidIrohaQuantityFailsInsteadOfDisplayingRoundedAmount() throws {
        let baseUnits = String(repeating: "9", count: 66)
        let client = FakeIrohaToriiClient(
            response: Self.mcpResponse([
                Self.instruction(
                    value: [
                        "source": .string("\(Self.assetId)#\(Self.address)"),
                        "destination": .string(Self.counterparty),
                        "object": .object([
                            "mantissa": .string(baseUnits),
                            "scale": .int(9)
                        ])
                    ]
                )
            ])
        )

        XCTAssertThrowsError(
            try execute(
                IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: Self.irohaAsset,
                    chain: Self.irohaChain(),
                    address: Self.address,
                    filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                    pagination: Pagination(count: 10)
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? IrohaHistoryReadError,
                .invalidMcpResponse("invalid_asset_transfer")
            )
        }
    }

    func testRejectsAssetSourcesThatOnlyContainWalletAddressAsSubstring() throws {
        let client = FakeIrohaToriiClient(
            response: Self.mcpResponse([
                Self.instruction(
                    value: [
                        "source": .string("\(Self.assetId)#prefix\(Self.address)suffix"),
                        "destination": .string(Self.counterparty),
                        "object": .string("1.23")
                    ]
                )
            ])
        )

        XCTAssertThrowsError(try executeHistory(client: client))
    }

    func testRejectsCaseMutatedNoncanonicalI105SourceAccounts() throws {
        let caseMutatedAddress = "T\(Self.address.dropFirst())"
        let client = FakeIrohaToriiClient(
            response: Self.mcpResponse([
                Self.instruction(
                    value: [
                        "source": .string("\(Self.assetId)#\(caseMutatedAddress)"),
                        "destination": .string(Self.counterparty),
                        "object": .string("1.23")
                    ]
                )
            ])
        )

        XCTAssertThrowsError(try executeHistory(client: client))
    }

    func testRejectsEveryNoncanonicalCommittedTransactionStatus() throws {
        for transactionStatus in [nil, "Pending", "Expired", "Commited"] as [String?] {
            let client = FakeIrohaToriiClient(
                response: Self.mcpResponse([
                    Self.instruction(transactionStatus: transactionStatus)
                ])
            )

            XCTAssertThrowsError(
                try execute(
                    IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                        asset: Self.irohaAsset,
                        chain: Self.irohaChain(),
                        address: Self.address,
                        filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                        pagination: Pagination(count: 10)
                    )
                )
            ) { error in
                XCTAssertEqual(
                    error as? IrohaHistoryReadError,
                    transactionStatus == nil
                        ? .invalidMcpResponse("invalid_history_item")
                        : .nonCommittedStatus(transactionStatus)
                )
            }
        }
    }

    func testRejectsLegacyAndAmbiguousTopLevelHistoryFieldAliases() throws {
        var genericStatus = Self.instruction(transactionStatus: nil)
        genericStatus["status"] = .string("Committed")
        var camelStatus = Self.instruction()
        camelStatus["transactionStatus"] = .string("Committed")
        var camelHash = Self.instruction()
        camelHash["transactionHash"] = .string(String(repeating: "b", count: 63) + "1")
        var camelTimestamp = Self.instruction()
        camelTimestamp["createdAt"] = .string("2024-01-01T00:00:00Z")

        for instruction in [genericStatus, camelStatus, camelHash, camelTimestamp] {
            let client = FakeIrohaToriiClient(response: Self.mcpResponse([instruction]))

            XCTAssertThrowsError(
                try execute(
                    IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                        asset: Self.irohaAsset,
                        chain: Self.irohaChain(),
                        address: Self.address,
                        filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                        pagination: Pagination(count: 10)
                    )
                )
            ) { error in
                XCTAssertEqual(
                    error as? IrohaHistoryReadError,
                    .invalidMcpResponse("invalid_history_item")
                )
            }
        }
    }

    func testRequiresExactAtomicBatchModeAndStableCanonicalIdentities() throws {
        let entries: [IrohaJSONValue] = [
            .object([
                "leg_id": .string("outgoing"),
                "from": .string(Self.address),
                "to": .string(Self.counterparty),
                "asset_definition": .string(Self.assetId),
                "amount": .string("1.25")
            ]),
            .object([
                "leg_id": .string("incoming"),
                "from": .string(Self.counterparty),
                "to": .string(Self.address),
                "asset_definition": .string(Self.assetId),
                "amount": .string("2")
            ])
        ]
        let batchValue: [String: IrohaJSONValue] = [
            "mode": .object(["mode": .string("Atomic"), "value": .null]),
            "entries": .array(entries)
        ]
        let instructions = [
            Self.instruction(index: 0),
            Self.instruction(index: 1),
            Self.instruction(value: batchValue, variant: "AssetBatch", index: 2, transactionHash: Self.txHash2)
        ]
        let result = try executeHistory(
            client: FakeIrohaToriiClient(response: Self.mcpResponse(instructions))
        )

        XCTAssertEqual(
            Set(result?.transactions.map(\.transactionId) ?? []),
            Set([
                "\(Self.txHash):0",
                "\(Self.txHash):1",
                "\(Self.txHash2):2:outgoing",
                "\(Self.txHash2):2:incoming"
            ])
        )

        let invalidModes: [IrohaJSONValue] = [
            .string("Atomic"),
            .object(["mode": .string("Independent"), "value": .null]),
            .object(["mode": .string("Atomic")]),
            .object(["mode": .string("Atomic"), "value": .null, "unexpected": .bool(true)])
        ]
        for mode in invalidModes {
            let invalidValue: [String: IrohaJSONValue] = ["mode": mode, "entries": .array(entries)]
            XCTAssertThrowsError(
                try executeHistory(
                    client: FakeIrohaToriiClient(
                        response: Self.mcpResponse([Self.instruction(value: invalidValue, variant: "AssetBatch")])
                    )
                )
            )
        }

        let duplicateEntry: IrohaJSONValue = .object([
            "leg_id": .string("duplicate"),
            "from": .string(Self.address),
            "to": .string(Self.counterparty),
            "asset_definition": .string(Self.assetId),
            "amount": .string("1")
        ])
        XCTAssertThrowsError(
            try executeHistory(
                client: FakeIrohaToriiClient(
                    response: Self.mcpResponse([
                        Self.instruction(
                            value: [
                                "mode": .object(["mode": .string("Atomic"), "value": .null]),
                                "entries": .array([duplicateEntry, duplicateEntry])
                            ],
                            variant: "AssetBatch"
                        )
                    ])
                )
            )
        )

        let oversizedUtf8Entry: IrohaJSONValue = .object([
            "leg_id": .string(String(repeating: "é", count: 129)),
            "from": .string(Self.address),
            "to": .string(Self.counterparty),
            "asset_definition": .string(Self.assetId),
            "amount": .string("1")
        ])
        XCTAssertThrowsError(
            try executeHistory(
                client: FakeIrohaToriiClient(
                    response: Self.mcpResponse([
                        Self.instruction(
                            value: [
                                "mode": .object(["mode": .string("Atomic"), "value": .null]),
                                "entries": .array([oversizedUtf8Entry])
                            ],
                            variant: "AssetBatch"
                        )
                    ])
                )
            )
        )
    }

    func testRejectsNoncanonicalNumericSpellingsAndValuesOutsideIrohaDomain() throws {
        let invalidAmounts: [IrohaJSONValue] = [
            .double(1.25),
            .string("+1"),
            .string("01"),
            .string("-0"),
            .string("1.0"),
            .string("1.20"),
            .string(".5"),
            .string("1."),
            .string(String(BigUInt(1) << 511)),
            .string(String(repeating: "9", count: 10_000))
        ]

        for amount in invalidAmounts {
            let value: [String: IrohaJSONValue] = [
                "source": .string("\(Self.assetId)#\(Self.address)"),
                "destination": .string(Self.counterparty),
                "object": amount
            ]
            XCTAssertThrowsError(
                try executeHistory(
                    client: FakeIrohaToriiClient(
                        response: Self.mcpResponse([Self.instruction(value: value)])
                    )
                )
            )
        }
    }

    func testRejectsMalformedCanonicalDtoFieldsAndRustRawIdentifierAlias() throws {
        var invalidItems: [[String: IrohaJSONValue]] = []
        func mutated(_ key: String, _ value: IrohaJSONValue) -> [String: IrohaJSONValue] {
            var result = Self.instruction()
            result[key] = value
            return result
        }
        invalidItems.append(mutated("transaction_hash", .string(Self.txHash.uppercased())))
        invalidItems.append(mutated("transaction_hash", .string("0x\(Self.txHash)")))
        invalidItems.append(mutated("transaction_hash", .string(String(repeating: "a", count: 64))))
        invalidItems.append(mutated("created_at", .int(1_704_067_200)))
        invalidItems.append(mutated("created_at", .string("2024-02-30T00:00:00Z")))
        invalidItems.append(mutated("index", .double(1.5)))
        invalidItems.append(mutated("block", .int(0)))
        invalidItems.append(mutated("kind", .string("Mint")))
        invalidItems.append(mutated("authority", .string("not-i105")))
        var extraItem = Self.instruction()
        extraItem["unexpected"] = .bool(true)
        invalidItems.append(extraItem)
        var rawIdentifierItem = Self.instruction()
        let canonicalBox = rawIdentifierItem.removeValue(forKey: "box")
        rawIdentifierItem["r#box"] = canonicalBox
        invalidItems.append(rawIdentifierItem)
        invalidItems.append(
            Self.instruction(value: [
                "source": .string("\(Self.assetId)#junk#\(Self.address)"),
                "destination": .string(Self.counterparty),
                "object": .string("1.25")
            ])
        )

        for (index, instruction) in invalidItems.enumerated() {
            XCTAssertThrowsError(
                try executeHistory(
                    client: FakeIrohaToriiClient(response: Self.mcpResponse([instruction]))
                ),
                "Malformed history fixture at index \(index) was accepted"
            )
        }
    }

    func testRequiresCoherentExactPaginationAndSnapshotBoundContext() throws {
        let invalidContexts = [
            [IrohaHistoryOperationFactory.paginationPageKey: "0"],
            [IrohaHistoryOperationFactory.paginationPageKey: "3"],
            [
                IrohaHistoryOperationFactory.paginationPageKey: "2",
                IrohaHistoryOperationFactory.paginationTotalPagesKey: "1",
                IrohaHistoryOperationFactory.paginationTotalItemsKey: "1"
            ]
        ]
        for context in invalidContexts {
            XCTAssertThrowsError(
                try executeHistory(
                    client: FakeIrohaToriiClient(response: Self.mcpResponse([Self.instruction()])),
                    pagination: Pagination(count: 10, context: context)
                )
            )
        }

        let malformedResponses = [
            Self.mcpResponse(
                [Self.instruction()],
                paginationOverride: [
                    "page": .int(1),
                    "per_page": .int(10),
                    "total_pages": .int(1)
                ]
            ),
            Self.mcpResponse(
                [Self.instruction()],
                paginationOverride: [
                    "page": .int(1),
                    "per_page": .int(10),
                    "total_pages": .int(1),
                    "total_items": .int(1),
                    "unexpected": .bool(true)
                ]
            ),
            Self.mcpResponse([Self.instruction()], bodyExtras: ["unexpected": .bool(true)]),
            Self.mcpResponse([Self.instruction()], totalItems: 2)
        ]
        for response in malformedResponses {
            XCTAssertThrowsError(try executeHistory(client: FakeIrohaToriiClient(response: response)))
        }

        let drifted = Self.mcpResponse([Self.instruction()], page: 2, totalItems: 12)
        XCTAssertThrowsError(
            try executeHistory(
                client: FakeIrohaToriiClient(response: drifted),
                pagination: Pagination(count: 10, context: [
                    IrohaHistoryOperationFactory.paginationPageKey: "2",
                    IrohaHistoryOperationFactory.paginationTotalPagesKey: "2",
                    IrohaHistoryOperationFactory.paginationTotalItemsKey: "11"
                ])
            )
        )
    }

    private func execute(
        _ wrapper: CompoundOperationWrapper<AssetTransactionPageData?>
    ) throws -> AssetTransactionPageData? {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    private func executeHistory(
        client: IrohaToriiClientProtocol,
        pagination: Pagination = Pagination(count: 10)
    ) throws -> AssetTransactionPageData? {
        try execute(
            IrohaHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.irohaAsset,
                chain: Self.irohaChain(),
                address: Self.address,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: pagination
            )
        )
    }

    private final class FakeIrohaToriiClient: IrohaToriiClientProtocol {
        private let response: IrohaMcpJsonRPCResponse
        private let definitionScale: Int?
        private let definitionCountMode: IrohaToriiCountMode

        private(set) var mcpCalls = 0
        private(set) var lastRequest: IrohaMcpJsonRPCRequest?
        private(set) var lastNetwork: UniversalWalletRegistry.IrohaNetwork?
        private(set) var lastBaseURL: String?
        private(set) var lastDefinitionsLimit: Int?
        private(set) var lastDefinitionsOffset: Int64?
        private(set) var lastDefinitionsCountMode: IrohaToriiCountMode?

        init(
            response: IrohaMcpJsonRPCResponse = IrohaHistoryOperationFactoryTests.mcpResponse([]),
            definitionScale: Int? = 9,
            definitionCountMode: IrohaToriiCountMode = .bounded
        ) {
            self.response = response
            self.definitionScale = definitionScale
            self.definitionCountMode = definitionCountMode
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

        func assetDefinitions(
            baseURL _: String?,
            limit: Int?,
            offset: Int64?,
            countMode: IrohaToriiCountMode?
        ) async throws -> IrohaAssetDefinitionListResponse {
            lastDefinitionsLimit = limit
            lastDefinitionsOffset = offset
            lastDefinitionsCountMode = countMode
            return IrohaAssetDefinitionListResponse(
                items: [
                    IrohaAssetDefinitionListItem(
                        id: IrohaHistoryOperationFactoryTests.assetId,
                        name: "XOR",
                        alias: nil,
                        ownedBy: nil,
                        metadata: nil,
                        aliasBinding: nil,
                        spec: IrohaAssetDefinitionSpec(scale: definitionScale)
                    )
                ],
                hasMore: false,
                countMode: definitionCountMode.rawValue,
                total: 1
            )
        }

        func submitTransactionAndWait(
            noritoBytes _: Data,
            expectedHash _: String,
            timeoutMilliseconds _: Int64,
            pollIntervalMilliseconds _: Int64,
            network _: UniversalWalletRegistry.IrohaNetwork,
            baseURL _: String?
        ) async throws -> IrohaSubmitAndWaitOutcome {
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
    private static let assetId = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"
    private static let txHash = String(repeating: "ab", count: 31) + "a1"
    private static let txHash2 = String(repeating: "cd", count: 31) + "e3"
    private static var counterparty: String {
        try! IrohaKeyDerivation.deriveAddress(
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow",
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105
    }
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
        precision: 9,
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

    private static func mcpResponse(
        _ instructions: [[String: IrohaJSONValue]],
        headers: [String: IrohaJSONValue] = completeFanoutHeaders,
        page: Int64 = 1,
        perPage: Int64 = 10,
        totalItems: Int64? = nil,
        paginationOverride: [String: IrohaJSONValue]? = nil,
        bodyExtras: [String: IrohaJSONValue] = [:]
    ) -> IrohaMcpJsonRPCResponse {
        let resolvedTotalItems = totalItems ?? Int64(instructions.count)
        let totalPages = resolvedTotalItems == 0 ? 0 : ((resolvedTotalItems - 1) / perPage) + 1
        let pagination = paginationOverride ?? [
            "page": .int(page),
            "per_page": .int(perPage),
            "total_pages": .int(totalPages),
            "total_items": .int(resolvedTotalItems)
        ]
        var body: [String: IrohaJSONValue] = [
            "items": .array(instructions.map { .object($0) }),
            "pagination": .object(pagination)
        ]
        body.merge(bodyExtras) { _, new in new }

        return IrohaMcpJsonRPCResponse(
            jsonrpc: "2.0",
            id: .string("history-\(page)"),
            result: .object([
                "isError": .bool(false),
                "structuredContent": .object([
                    "status": .int(200),
                    "headers": .object(headers),
                    "content_type": .string("application/json"),
                    "body": .object(body)
                ])
            ]),
            error: nil
        )
    }

    private static let completeFanoutHeaders: [String: IrohaJSONValue] = [
        "x-iroha-fanout-routes-attempted": .string("1"),
        "x-iroha-fanout-routes-succeeded": .string("1"),
        "x-iroha-fanout-routes-failed": .string("0"),
        "x-iroha-fanout-routes-denied": .string("0"),
        "x-iroha-fanout-routes-unavailable": .string("0"),
        "x-iroha-fanout-routes-not-found": .string("0")
    ]

    private static func instruction(
        value: [String: IrohaJSONValue]? = nil,
        transactionStatus: String? = "Committed",
        variant: String = "Asset",
        index: Int64 = 0,
        transactionHash: String = txHash
    ) -> [String: IrohaJSONValue] {
        var instruction: [String: IrohaJSONValue] = [
            "authority": .string(address),
            "transaction_hash": .string(transactionHash),
            "created_at": .string("2024-01-01T00:00:00Z"),
            "kind": .string("Transfer"),
            "block": .int(1),
            "index": .int(index),
            "box": .object([
                "encoded": .string("0x00"),
                "framed_sha256": .string("0x\(String(repeating: "00", count: 32))"),
                "json": .object([
                    "kind": .string("Transfer"),
                    "payload": .object([
                        "variant": .string(variant),
                        "value": .object(value ?? [
                            "source": .string("\(assetId)#\(address)"),
                            "destination": .string(counterparty),
                            "object": .string("1.23")
                        ])
                    ]),
                    "wire_id": .string(variant == "AssetBatch" ? "iroha.transfer_batch" : "iroha.transfer"),
                    "encoded": .string("00")
                ])
            ])
        ]
        if let transactionStatus {
            instruction["transaction_status"] = .string(transactionStatus)
        }
        return instruction
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
