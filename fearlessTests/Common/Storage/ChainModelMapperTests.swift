import XCTest
@testable import fearless
import CoreData
import RobinHood
import SSFModels

final class ChainModelMapperTests: XCTestCase {
    func testStartupWrapperConvertsMandatoryGetterExceptionToSanitizedSwiftError() {
        let entityDescription = makeEntityDescription(
            managedObjectClass: CDChain.self,
            properties: []
        )
        let entity = CDChain(
            entity: entityDescription,
            insertInto: nil
        )
        let startupMapper: AnyCoreDataMapper<ChainModel, CDChain> =
            AnyCoreDataMapper(ChainModelMapper())

        XCTAssertThrowsError(
            try startupMapper.transform(entity: entity)
        ) { error in
            XCTAssertEqual(
                error as? SafeTransformableValueReaderError,
                .objectiveCException
            )
        }
    }

    func testThrowingNodeRelationshipFailsClosedAsSwiftError() throws {
        let nodeDescription = makeEntityDescription(
            managedObjectClass: CDChainNode.self,
            properties: []
        )
        let nodes = NSRelationshipDescription()
        nodes.name = "nodes"
        nodes.destinationEntity = nodeDescription
        nodes.minCount = 0
        nodes.maxCount = 0
        nodes.isOptional = true
        nodes.deleteRule = .nullifyDeleteRule

        let chainDescription = makeEntityDescription(
            managedObjectClass: CDChain.self,
            properties: [
                makeAttribute(name: "chainId", type: .stringAttributeType),
                makeAttribute(name: "name", type: .stringAttributeType),
                nodes
            ]
        )
        let context = try makeContext(
            entities: [chainDescription, nodeDescription]
        )
        let entity = CDChain(
            entity: chainDescription,
            insertInto: context
        )
        entity.setValue("throwing-node-chain", forKey: "chainId")
        entity.setValue("Throwing node chain", forKey: "name")
        let throwingNode = CDChainNode(
            entity: nodeDescription,
            insertInto: context
        )
        entity.setValue(NSSet(object: throwingNode), forKey: "nodes")

        XCTAssertThrowsError(
            try ChainModelMapper().transform(entity: entity)
        ) { error in
            XCTAssertEqual(
                error as? SafeTransformableValueReaderError,
                .objectiveCException
            )
        }
    }

    func testSaveAndFetchPreservesParaIdAndIdentityChain() throws {
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<ChainModel, CDChain> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )

        let chain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: "1000",
            name: "Asset Hub",
            xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://example.org")!, name: "Main", apikey: nil)],
            addressPrefix: 0,
            types: nil,
            icon: URL(string: "https://example.org/icon.png"),
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: "kusama"
        )

        let queue = OperationQueue()

        let saveOperation = repository.saveOperation({ [chain] }, { [] })
        queue.addOperations([saveOperation], waitUntilFinished: true)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetchOperation], waitUntilFinished: true)

        let fetchedChains = try fetchOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let fetched = try XCTUnwrap(fetchedChains.first(where: { $0.chainId == chain.chainId }))

        XCTAssertEqual(fetched.paraId, chain.paraId)
        XCTAssertEqual(fetched.identityChain, chain.identityChain)
    }

    func testTransformQuarantinesChainWithoutIdentifier() throws {
        let context = try createContext()
        let entity = CDChain(context: context)
        entity.name = "Malformed chain"

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertTrue(
            chain.chainId.hasPrefix(
                ChainModelMapper.quarantinedChainIdentifierPrefix
            )
        )
        XCTAssertEqual(chain.name, ChainModelMapper.quarantinedChainName)
        XCTAssertTrue(chain.disabled)
        XCTAssertTrue(chain.nodes.isEmpty)
        XCTAssertTrue(chain.assets.isEmpty)
    }

    func testTransformQuarantinesNoncanonicalIdentifierUntilCleanup() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        entity.chainId = " valid-chain "

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertTrue(
            chain.chainId.hasPrefix(
                ChainModelMapper.quarantinedChainIdentifierPrefix
            )
        )
        XCTAssertTrue(chain.disabled)
    }

    func testTransformQuarantinesNameButKeepsIdentifierAndPreferences() throws {
        let context = try createContext()
        let entity = CDChain(context: context)
        entity.chainId = "malformed-chain"
        let customNode = CDChainNode(context: context)
        customNode.url = try XCTUnwrap(URL(string: "wss://custom.example"))
        customNode.name = "Custom"
        entity.customNodes = NSSet(object: customNode)
        entity.selectedNode = customNode

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertEqual(chain.chainId, "malformed-chain")
        XCTAssertEqual(chain.name, ChainModelMapper.quarantinedChainName)
        XCTAssertTrue(chain.disabled)
        XCTAssertEqual(chain.customNodes, Set([try makeNode(from: customNode)]))
        XCTAssertEqual(chain.selectedNode, try makeNode(from: customNode))
    }

    func testTransformSkipsDefaultNodeWithoutURL() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let node = CDChainNode(context: context)
        node.name = "Malformed node"
        entity.nodes = NSSet(object: node)

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertTrue(chain.nodes.isEmpty)
    }

    func testTransformSkipsSelectedNodeWithoutName() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let node = CDChainNode(context: context)
        node.url = try XCTUnwrap(URL(string: "wss://malformed.example"))
        entity.selectedNode = node

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertNil(chain.selectedNode)
    }

    func testTransformSkipsSelectedNodeWithUnusableURL() throws {
        let context = try createContext()
        let unusableURLs = [
            try XCTUnwrap(URL(string: "http:relative")),
            try XCTUnwrap(URL(string: "relative/node")),
            try XCTUnwrap(URL(string: "file:///tmp/not-a-node")),
            try XCTUnwrap(URL(string: "data:text/plain,not-a-node"))
        ]

        for (index, unusableURL) in unusableURLs.enumerated() {
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "invalid-node-\(index)"
            let node = CDChainNode(context: context)
            node.url = unusableURL
            node.name = "Unusable"
            entity.selectedNode = node

            let chain = try ChainModelMapper().transform(entity: entity)

            XCTAssertNil(chain.selectedNode, "\(unusableURL) must be ignored")
        }
    }

    func testTransformAcceptsSubstrateWebSocketNodeURLs() throws {
        let context = try createContext()
        let supportedURLs = [
            try XCTUnwrap(URL(string: "wss://node.example")),
            try XCTUnwrap(URL(string: "ws://127.0.0.1:9944"))
        ]

        for (index, supportedURL) in supportedURLs.enumerated() {
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "valid-node-\(index)"
            let node = CDChainNode(context: context)
            node.url = supportedURL
            node.name = "Supported"
            entity.nodes = NSSet(object: node)
            entity.selectedNode = node

            let chain = try ChainModelMapper().transform(entity: entity)

            XCTAssertEqual(chain.selectedNode?.url, supportedURL)
            XCTAssertFalse(chain.disabled)
        }
    }

    func testTransformKeepsCompatibleCustomNodeAsOnlyRuntimeEndpoint()
        throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let customNode = CDChainNode(context: context)
        customNode.url = try XCTUnwrap(
            URL(string: "wss://custom-only.example")
        )
        customNode.name = "Custom only"
        entity.customNodes = NSSet(object: customNode)

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertTrue(chain.nodes.isEmpty)
        XCTAssertNil(chain.selectedNode)
        XCTAssertEqual(
            chain.customNodes,
            Set([try makeNode(from: customNode)])
        )
        XCTAssertFalse(chain.disabled)
    }

    func testTransformDisablesChainWithOnlyIncompatibleCustomNode() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let customNode = CDChainNode(context: context)
        customNode.url = try XCTUnwrap(
            URL(string: "https://not-a-substrate-websocket.example")
        )
        customNode.name = "Wrong runtime protocol"
        entity.customNodes = NSSet(object: customNode)

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertTrue(chain.nodes.isEmpty)
        XCTAssertNil(chain.selectedNode)
        XCTAssertEqual(chain.customNodes, Set<ChainNodeModel>())
        XCTAssertTrue(chain.disabled)
    }

    func testTransformRejectsHTTPNodesForSubstrateRuntime() throws {
        let context = try createContext()
        let incompatibleURLs = [
            try XCTUnwrap(URL(string: "https://node.example")),
            try XCTUnwrap(URL(string: "http://localhost:8080"))
        ]

        for (index, incompatibleURL) in incompatibleURLs.enumerated() {
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "incompatible-substrate-\(index)"
            let node = CDChainNode(context: context)
            node.url = incompatibleURL
            node.name = "Wrong runtime protocol"
            entity.nodes = NSSet(object: node)
            entity.selectedNode = node

            let chain = try ChainModelMapper().transform(entity: entity)

            XCTAssertTrue(chain.nodes.isEmpty)
            XCTAssertNil(chain.selectedNode)
            XCTAssertTrue(chain.disabled)
        }
    }

    func testTransformAcceptsOnlySecureEthereumRuntimeSchemes() throws {
        let context = try createContext()
        let candidates: [(String, Bool)] = [
            ("https://rpc.example", true),
            ("wss://rpc.example", true),
            ("http://rpc.example", false),
            ("ws://rpc.example", false)
        ]

        for (index, candidate) in candidates.enumerated() {
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "ethereum-runtime-\(index)"
            entity.options = NSArray(object: ChainOptions.ethereum.rawValue)
            let node = CDChainNode(context: context)
            node.url = try XCTUnwrap(URL(string: candidate.0))
            node.name = "Ethereum RPC"
            entity.nodes = NSSet(object: node)
            entity.selectedNode = node

            let chain = try ChainModelMapper().transform(entity: entity)

            if candidate.1 {
                XCTAssertEqual(chain.selectedNode?.url, node.url)
                XCTAssertFalse(chain.disabled)
            } else {
                XCTAssertTrue(chain.nodes.isEmpty)
                XCTAssertNil(chain.selectedNode)
                XCTAssertTrue(chain.disabled)
            }
        }
    }

    func testTransformAppliesStrictTonServerShape() throws {
        let context = try createContext()
        let candidates: [(String, Bool)] = [
            ("https://tonapi.io", true),
            ("https://tonapi.io/", true),
            ("https://tonapi.io/path", false),
            ("https://user@tonapi.io", false),
            ("http://tonapi.io", false),
            ("wss://tonapi.io", false)
        ]

        for (index, candidate) in candidates.enumerated() {
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "ton-runtime-\(index)"
            entity.name = "TON Mainnet"
            let node = CDChainNode(context: context)
            node.url = try XCTUnwrap(URL(string: candidate.0))
            node.name = "TON API"
            entity.nodes = NSSet(object: node)
            entity.selectedNode = node

            let chain = try ChainModelMapper().transform(entity: entity)

            if candidate.1 {
                XCTAssertEqual(chain.selectedNode?.url, node.url)
                XCTAssertFalse(chain.disabled)
            } else {
                XCTAssertTrue(chain.nodes.isEmpty)
                XCTAssertNil(chain.selectedNode)
                XCTAssertTrue(chain.disabled)
            }
        }
    }

    func testTransformKeepsValidNodesWhileSkippingMalformedOnes() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let validNode = CDChainNode(context: context)
        validNode.url = try XCTUnwrap(URL(string: "wss://valid.example"))
        validNode.name = "Valid"
        let malformedNode = CDChainNode(context: context)
        malformedNode.name = "Malformed"
        entity.nodes = NSSet(array: [malformedNode, validNode])

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertEqual(chain.nodes.count, 1)
        XCTAssertEqual(chain.nodes.first?.url, validNode.url)
    }

    func testPopulateRoundTripPreservesValidStandaloneSelectedNode() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let defaultNode = ChainNodeModel(
            url: try XCTUnwrap(
                URL(string: "wss://default-round-trip.example")
            ),
            name: "Default",
            apikey: nil
        )
        let standaloneSelection = ChainNodeModel(
            url: try XCTUnwrap(
                URL(string: "wss://standalone-selection.example")
            ),
            name: "Standalone selection",
            apikey: nil
        )
        let model = ChainModel(
            rank: 1,
            disabled: false,
            chainId: "standalone-selection-chain",
            paraId: nil,
            name: "Standalone selection chain",
            xcm: nil,
            nodes: [defaultNode],
            addressPrefix: 42,
            icon: nil,
            selectedNode: standaloneSelection,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        try ChainModelMapper().populate(
            entity: entity,
            from: model,
            using: context
        )

        let selectedEntity = try XCTUnwrap(entity.selectedNode)
        XCTAssertFalse(
            (entity.nodes as? Set<CDChainNode>)?
                .contains(selectedEntity) ?? true
        )
        XCTAssertFalse(
            (entity.customNodes as? Set<CDChainNode>)?
                .contains(selectedEntity) ?? false
        )

        let transformed = try ChainModelMapper().transform(entity: entity)

        XCTAssertEqual(transformed.nodes, Set([defaultNode]))
        XCTAssertEqual(transformed.selectedNode, standaloneSelection)
        XCTAssertFalse(transformed.disabled)
    }

    func testTransformDropsUnsupportedStandaloneSelectionButKeepsHealthyChain()
        throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let defaultNode = CDChainNode(context: context)
        defaultNode.url = try XCTUnwrap(
            URL(string: "wss://healthy-default.example")
        )
        defaultNode.name = "Healthy default"
        entity.nodes = NSSet(object: defaultNode)

        let unsupportedSelection = CDChainNode(context: context)
        unsupportedSelection.url = try XCTUnwrap(
            URL(string: "https://not-a-substrate-websocket.example")
        )
        unsupportedSelection.name = "Unsupported standalone selection"
        entity.selectedNode = unsupportedSelection

        let transformed = try ChainModelMapper().transform(entity: entity)

        XCTAssertEqual(transformed.nodes.count, 1)
        XCTAssertEqual(transformed.nodes.first?.url, defaultNode.url)
        XCTAssertNil(transformed.selectedNode)
        XCTAssertFalse(transformed.disabled)
    }

    func testTransformSkipsMalformedCachedAsset() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let malformedAsset = CDAsset(context: context)
        malformedAsset.name = "Missing identifier"
        entity.assets = NSSet(object: malformedAsset)

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertTrue(chain.assets.isEmpty)
    }

    func testTransformIgnoresRelationshipWithOnlyMalformedPrices()
        throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let assetEntity = CDAsset(context: context)
        let expectedAsset = ChainModelGenerator.generateAssetWithId(
            "valid-asset",
            symbol: "VAL",
            assetPresicion: 12
        )
        try AssetModelMapper().populate(
            entity: assetEntity,
            from: expectedAsset,
            using: context
        )
        let malformedPrice = CDPriceData(context: context)
        assetEntity.setValue(
            NSSet(object: malformedPrice),
            forKey: "priceData"
        )
        entity.assets = NSSet(object: assetEntity)

        let chain = try ChainModelMapper().transform(entity: entity)

        XCTAssertEqual(chain.assets, Set([expectedAsset]))
    }

    func testCachedPriceExtractionRejectsUnexpectedEntityBeforeReadingUndefinedKeys() {
        let entity = NSEntityDescription()
        entity.name = "UnexpectedCachedPrice"
        entity.managedObjectClassName = NSStringFromClass(
            NSManagedObject.self
        )
        let model = NSManagedObjectModel()
        model.entities = [entity]
        let unexpectedRow = NSManagedObject(
            entity: entity,
            insertInto: nil
        )

        XCTAssertNil(
            ChainModelMapper().createPriceData(from: unexpectedRow)
        )
    }

    func testCachedPriceExtractionSkipsRowWhenAttributeReadRaisesException() {
        let fixture = makeCachedPriceEntity(
            managedObjectClass: ExceptionRaisingCachedPrice.self,
            priceType: .stringAttributeType
        )
        let row = ExceptionRaisingCachedPrice(
            entity: fixture.entity,
            insertInto: nil
        )
        row.setValue("usd", forKey: "currencyId")
        row.setValue("dot", forKey: "priceId")

        XCTAssertNil(ChainModelMapper().createPriceData(from: row))
    }

    func testCachedPriceExtractionPreservesLegacyDecimalWithoutOptionalFields() throws {
        let fixture = makeCachedPriceEntity(
            managedObjectClass: NSManagedObject.self,
            priceType: .decimalAttributeType
        )
        let row = NSManagedObject(
            entity: fixture.entity,
            insertInto: nil
        )
        row.setValue("usd", forKey: "currencyId")
        row.setValue("dot", forKey: "priceId")
        row.setValue(
            NSDecimalNumber(string: "12.5"),
            forKey: "price"
        )

        let priceData = try XCTUnwrap(
            ChainModelMapper().createPriceData(from: row)
        )

        XCTAssertEqual(priceData.currencyId, "usd")
        XCTAssertEqual(priceData.priceId, "dot")
        XCTAssertEqual(priceData.price, "12.5")
        XCTAssertNil(priceData.fiatDayChange)
        XCTAssertNil(priceData.coingeckoPriceId)
    }

    func testTransformUsesSingleValidUnmatchedCachedPrice() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let asset = makeAssetWithUnmatchedPricing(identifier: "single-price")
        let assetEntity = CDAsset(context: context)
        try AssetModelMapper().populate(
            entity: assetEntity,
            from: asset,
            using: context
        )
        let cachedPrice = makeCachedPrice(
            currencyId: "unmatched-currency",
            priceId: "unmatched-price",
            price: "7.25",
            fiatDayChange: "-0.5",
            in: context
        )
        assetEntity.setValue(
            NSSet(object: cachedPrice),
            forKey: "priceData"
        )
        entity.assets = NSSet(object: assetEntity)

        let chain = try ChainModelMapper().transform(entity: entity)
        let transformedAsset = try XCTUnwrap(
            chain.assets.first { $0.id == asset.id }
        )

        XCTAssertEqual(transformedAsset.price, Decimal(string: "7.25"))
        XCTAssertEqual(
            transformedAsset.fiatDayChange,
            Decimal(string: "-0.5")
        )
    }

    func testTransformDeterministicallyChoosesCanonicalUnmatchedCachedPrice()
        throws {
        let priceFixtures = [
            (
                currencyId: "z-currency",
                priceId: "z-price",
                price: "99.5",
                fiatDayChange: "9.5"
            ),
            (
                currencyId: "a-currency",
                priceId: "a-price",
                price: "1.25",
                fiatDayChange: "-1.5"
            )
        ]

        for shouldReverseInsertion in [false, true] {
            let context = try createContext()
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "two-prices-\(shouldReverseInsertion)"
            let asset = makeAssetWithUnmatchedPricing(
                identifier: "two-prices-\(shouldReverseInsertion)"
            )
            let assetEntity = CDAsset(context: context)
            try AssetModelMapper().populate(
                entity: assetEntity,
                from: asset,
                using: context
            )
            let orderedFixtures = shouldReverseInsertion
                ? Array(priceFixtures.reversed())
                : priceFixtures
            let cachedPrices = orderedFixtures.map {
                makeCachedPrice(
                    currencyId: $0.currencyId,
                    priceId: $0.priceId,
                    price: $0.price,
                    fiatDayChange: $0.fiatDayChange,
                    in: context
                )
            }
            assetEntity.setValue(
                NSSet(array: cachedPrices),
                forKey: "priceData"
            )
            entity.assets = NSSet(object: assetEntity)

            let chain = try ChainModelMapper().transform(entity: entity)
            let transformedAsset = try XCTUnwrap(
                chain.assets.first { $0.id == asset.id }
            )

            XCTAssertEqual(
                transformedAsset.price,
                Decimal(string: "1.25")
            )
            XCTAssertEqual(
                transformedAsset.fiatDayChange,
                Decimal(string: "-1.5")
            )
        }
    }

    func testTransformUsesValidCachedPriceAmongMalformedRows() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let asset = makeAssetWithUnmatchedPricing(identifier: "mixed-prices")
        let assetEntity = CDAsset(context: context)
        try AssetModelMapper().populate(
            entity: assetEntity,
            from: asset,
            using: context
        )
        let missingCurrency = CDPriceData(context: context)
        missingCurrency.priceId = "missing-currency"
        missingCurrency.price = "100"
        let missingPriceIdentifier = CDPriceData(context: context)
        missingPriceIdentifier.currencyId = "missing-price-id"
        missingPriceIdentifier.price = "200"
        let missingPrice = CDPriceData(context: context)
        missingPrice.currencyId = "missing-price"
        missingPrice.priceId = "missing-price"
        let validPrice = makeCachedPrice(
            currencyId: "valid-unmatched-currency",
            priceId: "valid-unmatched-price",
            price: "3.75",
            fiatDayChange: "0.75",
            in: context
        )
        assetEntity.setValue(
            NSSet(
                array: [
                    missingCurrency,
                    validPrice,
                    missingPriceIdentifier,
                    missingPrice
                ]
            ),
            forKey: "priceData"
        )
        entity.assets = NSSet(object: assetEntity)

        let chain = try ChainModelMapper().transform(entity: entity)
        let transformedAsset = try XCTUnwrap(
            chain.assets.first { $0.id == asset.id }
        )

        XCTAssertEqual(transformedAsset.price, Decimal(string: "3.75"))
        XCTAssertEqual(
            transformedAsset.fiatDayChange,
            Decimal(string: "0.75")
        )
    }

    func testTransformRejectsMalformedNonfiniteAndNegativeCachedPrices()
        throws {
        let invalidPrices = [
            "",
            " ",
            "not-a-price",
            "NaN",
            "Infinity",
            "-Infinity",
            "1e9999",
            "-0.01",
            "1,23",
            "0x10"
        ]

        for shouldReverseInsertion in [false, true] {
            let context = try createContext()
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "invalid-prices-\(shouldReverseInsertion)"
            let asset = makeAssetWithUnmatchedPricing(
                identifier: "invalid-prices-\(shouldReverseInsertion)"
            )
            let assetEntity = CDAsset(context: context)
            try AssetModelMapper().populate(
                entity: assetEntity,
                from: asset,
                using: context
            )
            let invalidRows = invalidPrices.enumerated().map {
                makeCachedPrice(
                    currencyId: String(
                        format: "a-invalid-%02d",
                        $0.offset
                    ),
                    priceId: "asset-price",
                    price: $0.element,
                    fiatDayChange: "99",
                    in: context
                )
            }
            let validFallback = makeCachedPrice(
                currencyId: "z-valid-currency",
                priceId: "asset-price",
                price: "4.25",
                fiatDayChange: "-0.25",
                in: context
            )
            let rows = shouldReverseInsertion
                ? [validFallback] + Array(invalidRows.reversed())
                : invalidRows + [validFallback]
            assetEntity.setValue(
                NSSet(array: Array(rows)),
                forKey: "priceData"
            )
            entity.assets = NSSet(object: assetEntity)

            let chain = try ChainModelMapper().transform(entity: entity)
            let transformedAsset = try XCTUnwrap(
                chain.assets.first { $0.id == asset.id }
            )

            XCTAssertEqual(
                transformedAsset.price,
                Decimal(string: "4.25")
            )
            XCTAssertEqual(
                transformedAsset.fiatDayChange,
                Decimal(string: "-0.25")
            )
        }
    }

    func testTransformPreservesSupportedCachedPriceStringFormats() throws {
        let fixtures: [(String, Decimal)] = [
            ("0", 0),
            (".5", 0.5),
            ("+7.5", 7.5),
            ("1.25e2", 125),
            (" 9.75 ", 9.75)
        ]

        for (index, fixture) in fixtures.enumerated() {
            let context = try createContext()
            let entity = makeValidChainEntity(in: context)
            entity.chainId = "valid-price-format-\(index)"
            let asset = makeAssetWithUnmatchedPricing(
                identifier: "valid-price-format-\(index)"
            )
            let assetEntity = CDAsset(context: context)
            try AssetModelMapper().populate(
                entity: assetEntity,
                from: asset,
                using: context
            )
            let cachedPrice = makeCachedPrice(
                currencyId: "format-currency",
                priceId: "asset-price",
                price: fixture.0,
                fiatDayChange: "0",
                in: context
            )
            assetEntity.setValue(
                NSSet(object: cachedPrice),
                forKey: "priceData"
            )
            entity.assets = NSSet(object: assetEntity)

            let chain = try ChainModelMapper().transform(entity: entity)
            let transformedAsset = try XCTUnwrap(
                chain.assets.first { $0.id == asset.id }
            )

            XCTAssertEqual(
                transformedAsset.price,
                fixture.1,
                "expected cached price format \(fixture.0)"
            )
        }
    }

    func testPopulateDeletesMalformedStaleNodesInsteadOfForceUnwrapping() throws {
        let context = try createContext()
        let entity = makeValidChainEntity(in: context)
        let malformedDefaultNode = CDChainNode(context: context)
        malformedDefaultNode.name = "Malformed default"
        let malformedCustomNode = CDChainNode(context: context)
        malformedCustomNode.name = "Malformed custom"
        entity.nodes = NSSet(object: malformedDefaultNode)
        entity.customNodes = NSSet(object: malformedCustomNode)
        let replacement = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42
        ).replacingCustomNodes([])

        try ChainModelMapper().populate(
            entity: entity,
            from: replacement,
            using: context
        )

        XCTAssertTrue(malformedDefaultNode.isDeleted)
        XCTAssertTrue(malformedCustomNode.isDeleted)
        XCTAssertFalse(entity.nodes?.allObjects.isEmpty ?? true)
        XCTAssertTrue(entity.customNodes?.allObjects.isEmpty ?? true)
    }

    func testMalformedChainCleanup_whenGetterRaisesDuringQuarantine_thenFailsSafelyAndRollsBack() throws {
        let chainEntity = NSEntityDescription()
        chainEntity.name = String(describing: CDChain.self)
        chainEntity.managedObjectClassName = NSStringFromClass(
            CDChain.self
        )
        let disabled = NSAttributeDescription()
        disabled.name = "disabled"
        disabled.attributeType = .booleanAttributeType
        disabled.isOptional = false
        disabled.defaultValue = false
        chainEntity.properties = [
            makeAttribute(
                name: "chainId",
                type: .stringAttributeType
            ),
            disabled
        ]

        let model = NSManagedObjectModel()
        model.entities = [chainEntity]
        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil
        )
        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator
        let facade = ChainCleanupFixtureStorageFacade(
            context: context
        )

        try perform(in: facade.databaseService) {
            context in

            let chain = CDChain(
                entity: chainEntity,
                insertInto: context
            )
            chain.chainId = ""
            chain.disabled = false
            try context.save()
        }

        let operation = ChainRepositoryFactory(
            storageFacade: facade
        ).createMalformedChainCleanupOperation()
        let queue = OperationQueue()
        queue.addOperations(
            [operation],
            waitUntilFinished: true
        )

        XCTAssertThrowsError(
            try XCTUnwrap(operation.result).get()
        ) { error in
            XCTAssertEqual(
                error as? SafeTransformableValueReaderError,
                .objectiveCException
            )
        }

        try perform(in: facade.databaseService) {
            context in

            let request = NSFetchRequest<CDChain>(
                entityName: String(describing: CDChain.self)
            )
            let chains = try context.fetch(request)
            let chain = try XCTUnwrap(chains.first)
            XCTAssertEqual(chains.count, 1)
            XCTAssertEqual(chain.chainId, "")
            XCTAssertFalse(chain.disabled)
            XCTAssertFalse(
                chain.chainId?.hasPrefix(
                    ChainModelMapper
                        .quarantinedChainIdentifierPrefix
                ) == true
            )
        }
    }

    func testMalformedChainCleanupQuarantinesBlankIdentifiersWithoutDataLoss()
        throws {
        let facade = SubstrateStorageTestFacade()
        let malformedFixtures: [(identifier: String?, suffix: String)] = [
            ("", "empty"),
            (" \n\t", "whitespace")
        ]

        try perform(in: facade.databaseService) { context in
            for fixture in malformedFixtures {
                let malformedChain = CDChain(context: context)
                malformedChain.chainId = fixture.identifier
                malformedChain.name = "Malformed \(fixture.suffix)"

                let defaultNode = CDChainNode(context: context)
                defaultNode.url = try XCTUnwrap(
                    URL(
                        string:
                        "wss://default-\(fixture.suffix).example"
                    )
                )
                defaultNode.name = "Default \(fixture.suffix)"
                malformedChain.nodes = NSSet(object: defaultNode)

                let customNode = CDChainNode(context: context)
                customNode.url = try XCTUnwrap(
                    URL(
                        string:
                        "wss://custom-\(fixture.suffix).example"
                    )
                )
                customNode.name = "Custom \(fixture.suffix)"
                malformedChain.customNodes = NSSet(object: customNode)
                malformedChain.selectedNode = customNode

                let asset = CDAsset(context: context)
                asset.id = "asset-\(fixture.suffix)"
                asset.name = "Asset \(fixture.suffix)"
                asset.symbol = "AS\(fixture.suffix)"
                asset.precision = 12
                malformedChain.assets = NSSet(object: asset)
            }

            let healthyChain = CDChain(context: context)
            healthyChain.chainId = "healthy-chain"
            healthyChain.name = "Healthy"
            try context.save()
        }

        let factory = ChainRepositoryFactory(storageFacade: facade)
        let queue = OperationQueue()
        var identifiersAfterFirstCleanup: [String: String] = [:]

        for cleanupIndex in 0 ..< 2 {
            let cleanupOperation = factory.createMalformedChainCleanupOperation()
            queue.addOperations([cleanupOperation], waitUntilFinished: true)
            let _: Void = try XCTUnwrap(cleanupOperation.result).get()

            if cleanupIndex == 0 {
                try perform(in: facade.databaseService) { context in
                    let request = NSFetchRequest<CDChain>(
                        entityName: String(describing: CDChain.self)
                    )
                    identifiersAfterFirstCleanup = Dictionary(
                        uniqueKeysWithValues: try context.fetch(request)
                            .compactMap { chain in
                                guard
                                    let name = chain.name,
                                    name.hasPrefix("Malformed "),
                                    let identifier = chain.chainId
                                else {
                                    return nil
                                }

                                return (name, identifier)
                            }
                    )
                }
            }
        }

        try perform(in: facade.databaseService) { context in
            let request = NSFetchRequest<CDChain>(
                entityName: String(describing: CDChain.self)
            )
            let chains = try context.fetch(request)
            XCTAssertEqual(chains.count, malformedFixtures.count + 1)

            let healthy = try XCTUnwrap(
                chains.first { $0.chainId == "healthy-chain" }
            )
            XCTAssertFalse(healthy.disabled)

            let quarantinedChains = chains.filter {
                $0.chainId?.hasPrefix(
                    ChainModelMapper.quarantinedChainIdentifierPrefix
                ) == true
            }
            XCTAssertEqual(
                quarantinedChains.count,
                malformedFixtures.count
            )
            XCTAssertEqual(
                Set(quarantinedChains.compactMap(\.chainId)).count,
                malformedFixtures.count,
                "each malformed row must receive a unique identifier"
            )

            for fixture in malformedFixtures {
                let name = "Malformed \(fixture.suffix)"
                let chain = try XCTUnwrap(
                    quarantinedChains.first { $0.name == name }
                )
                XCTAssertTrue(chain.disabled)
                XCTAssertEqual(
                    chain.chainId,
                    identifiersAfterFirstCleanup[name],
                    "quarantine identifiers must remain stable on relaunch"
                )
                XCTAssertEqual(
                    Set(
                        (chain.nodes?.allObjects as? [CDChainNode] ?? [])
                            .compactMap(\.url?.absoluteString)
                    ),
                    Set(["wss://default-\(fixture.suffix).example"])
                )
                XCTAssertEqual(
                    Set(
                        (
                            chain.customNodes?.allObjects
                                as? [CDChainNode] ?? []
                        )
                        .compactMap(\.url?.absoluteString)
                    ),
                    Set(["wss://custom-\(fixture.suffix).example"])
                )
                XCTAssertEqual(
                    chain.selectedNode?.url?.absoluteString,
                    "wss://custom-\(fixture.suffix).example"
                )
                XCTAssertEqual(
                    Set(
                        (chain.assets?.allObjects as? [CDAsset] ?? [])
                            .compactMap(\.id)
                    ),
                    Set(["asset-\(fixture.suffix)"])
                )
            }
        }

        // Exercise the same repository fetch/map frame sequence as the
        // TestFlight _ArrayBuffer._getElementSlowPath crash after cleanup.
        let repository = factory.createRepository()
        let fetchOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        queue.addOperations([fetchOperation], waitUntilFinished: true)
        let chains: [ChainModel] = try XCTUnwrap(
            fetchOperation.result
        ).get()
        XCTAssertEqual(chains.count, malformedFixtures.count + 1)
        XCTAssertEqual(
            chains.filter {
                $0.chainId.hasPrefix(
                    ChainModelMapper.quarantinedChainIdentifierPrefix
                )
            }.count,
            malformedFixtures.count
        )
        for fixture in malformedFixtures {
            let chain = try XCTUnwrap(
                chains.first { $0.name == "Malformed \(fixture.suffix)" }
            )
            XCTAssertEqual(
                chain.customNodes?.first?.url.absoluteString,
                "wss://custom-\(fixture.suffix).example"
            )
            XCTAssertEqual(
                chain.selectedNode?.url.absoluteString,
                "wss://custom-\(fixture.suffix).example"
            )
            XCTAssertEqual(
                Set(chain.assets.map(\.id)),
                Set(["asset-\(fixture.suffix)"])
            )
        }
    }

    func testMalformedChainQuarantineCannotCollideWithStoredIdentifier()
        throws {
        let facade = SubstrateStorageTestFacade()
        var reservedIdentifier = ""

        try perform(in: facade.databaseService) { context in
            let malformedChain = CDChain(context: context)
            malformedChain.chainId = ""
            malformedChain.name = "Malformed collision"
            try context.save()

            reservedIdentifier =
                ChainModelMapper.quarantinedChainIdentifierPrefix +
                malformedChain.objectID.uriRepresentation().absoluteString

            let preexistingChain = CDChain(context: context)
            preexistingChain.chainId = reservedIdentifier
            preexistingChain.name = "Preexisting identifier"
            try context.save()
        }

        let factory = ChainRepositoryFactory(storageFacade: facade)
        let queue = OperationQueue()
        for _ in 0 ..< 2 {
            let cleanupOperation = factory.createMalformedChainCleanupOperation()
            queue.addOperations([cleanupOperation], waitUntilFinished: true)
            let _: Void = try XCTUnwrap(cleanupOperation.result).get()
        }

        try perform(in: facade.databaseService) { context in
            let request = NSFetchRequest<CDChain>(
                entityName: String(describing: CDChain.self)
            )
            let chains = try context.fetch(request)
            XCTAssertEqual(chains.count, 2)

            let preexistingChain = try XCTUnwrap(
                chains.first { $0.name == "Preexisting identifier" }
            )
            XCTAssertEqual(preexistingChain.chainId, reservedIdentifier)
            XCTAssertFalse(preexistingChain.disabled)

            let quarantinedChain = try XCTUnwrap(
                chains.first { $0.name == "Malformed collision" }
            )
            XCTAssertEqual(
                quarantinedChain.chainId,
                "\(reservedIdentifier)#1"
            )
            XCTAssertTrue(quarantinedChain.disabled)
        }
    }

    func testCleanupCanonicalizesIdentifiersAndMergesPreferencesWithoutLoss()
        throws {
        let facade = SubstrateStorageTestFacade()
        let canonicalSelectedURL = try XCTUnwrap(
            URL(string: "wss://canonical-user.example")
        )
        let collidingDefaultURL = try XCTUnwrap(
            URL(string: "wss://colliding-default.example")
        )
        let collidingCustomURL = try XCTUnwrap(
            URL(string: "wss://colliding-user.example")
        )
        let normalizedSelectedURL = try XCTUnwrap(
            URL(string: "wss://normalized-user.example")
        )
        let historyApiURL = try XCTUnwrap(
            URL(string: "https://history.example")
        )

        try perform(in: facade.databaseService) { context in
            let canonical = CDChain(context: context)
            canonical.chainId = "collision-chain"
            canonical.name = "Canonical"
            let canonicalNode = CDChainNode(context: context)
            canonicalNode.url = canonicalSelectedURL
            canonicalNode.name = "Canonical selection"
            canonical.nodes = NSSet(object: canonicalNode)
            canonical.customNodes = NSSet(object: canonicalNode)
            canonical.selectedNode = canonicalNode

            let colliding = CDChain(context: context)
            colliding.chainId = " collision-chain \n"
            colliding.name = "Canonical"
            colliding.rank = "7"
            colliding.historyApiType = "subquery"
            colliding.historyApiUrl = historyApiURL
            colliding.setValue(
                NSArray(object: ChainOptions.poolStaking.rawValue),
                forKey: "options"
            )
            let collidingDefaultNode = CDChainNode(context: context)
            collidingDefaultNode.url = collidingDefaultURL
            collidingDefaultNode.name = "Colliding default"
            colliding.nodes = NSSet(object: collidingDefaultNode)
            let collidingCustomNode = CDChainNode(context: context)
            collidingCustomNode.url = collidingCustomURL
            collidingCustomNode.name = "Colliding custom"
            colliding.customNodes = NSSet(object: collidingCustomNode)

            let collidingAsset = CDAsset(context: context)
            collidingAsset.id = "colliding-asset"
            collidingAsset.name = "Colliding asset"
            collidingAsset.symbol = "COL"
            collidingAsset.precision = 12
            colliding.assets = NSSet(object: collidingAsset)

            let collidingExplorer = CDExternalApi(context: context)
            collidingExplorer.type = "subscan"
            collidingExplorer.url = "https://explorer.example"
            collidingExplorer.setValue(
                NSArray(object: "extrinsic"),
                forKey: "types"
            )
            colliding.explorers = NSSet(object: collidingExplorer)

            let collidingXcm = CDChainXcmConfig(context: context)
            collidingXcm.xcmVersion = "V3"
            collidingXcm.availableAssets = NSSet()
            collidingXcm.availableDestinations = NSSet()
            colliding.xcmConfig = collidingXcm

            let normalizationOnly = CDChain(context: context)
            normalizationOnly.chainId = "\tnormalized-chain "
            normalizationOnly.name = "Normalization only"
            let normalizedNode = CDChainNode(context: context)
            normalizedNode.url = normalizedSelectedURL
            normalizedNode.name = "Normalized selection"
            normalizationOnly.nodes = NSSet(object: normalizedNode)
            normalizationOnly.customNodes = NSSet(object: normalizedNode)
            normalizationOnly.selectedNode = normalizedNode

            try context.save()
        }

        let factory = ChainRepositoryFactory(storageFacade: facade)
        let queue = OperationQueue()
        for _ in 0 ..< 2 {
            let operation = factory.createMalformedChainCleanupOperation()
            queue.addOperations([operation], waitUntilFinished: true)
            let _: Void = try XCTUnwrap(operation.result).get()
        }

        try perform(in: facade.databaseService) { context in
            let request = NSFetchRequest<CDChain>(
                entityName: String(describing: CDChain.self)
            )
            let chains = try context.fetch(request)
            let chainsByIdentifier = Dictionary(
                uniqueKeysWithValues: chains.compactMap { chain in
                    chain.chainId.map { ($0, chain) }
                }
            )

            XCTAssertEqual(
                Set(chainsByIdentifier.keys),
                Set(["collision-chain", "normalized-chain"])
            )

            let merged = try XCTUnwrap(
                chainsByIdentifier["collision-chain"]
            )
            let mergedCustomURLs = Set(
                (merged.customNodes?.allObjects as? [CDChainNode] ?? [])
                    .compactMap(\.url)
            )
            XCTAssertEqual(
                mergedCustomURLs,
                Set([canonicalSelectedURL, collidingCustomURL])
            )
            let mergedDefaultURLs = Set(
                (merged.nodes?.allObjects as? [CDChainNode] ?? [])
                    .compactMap(\.url)
            )
            XCTAssertEqual(
                mergedDefaultURLs,
                Set([canonicalSelectedURL, collidingDefaultURL])
            )
            XCTAssertEqual(
                merged.selectedNode?.url,
                canonicalSelectedURL,
                "the canonical row's explicit selection wins collisions"
            )
            XCTAssertEqual(merged.rank, "7")
            XCTAssertEqual(merged.historyApiType, "subquery")
            XCTAssertEqual(merged.historyApiUrl, historyApiURL)
            let mergedOptions: [String]? =
                try SafeTransformableValueReader.read(
                    from: merged,
                    key: "options"
                )
            XCTAssertEqual(
                mergedOptions,
                [ChainOptions.poolStaking.rawValue]
            )
            XCTAssertEqual(
                Set(
                    (merged.assets?.allObjects as? [CDAsset] ?? [])
                        .compactMap(\.id)
                ),
                Set(["colliding-asset"])
            )
            XCTAssertEqual(
                Set(
                    (
                        merged.explorers?.allObjects
                            as? [CDExternalApi] ?? []
                    )
                    .compactMap(\.url)
                ),
                Set(["https://explorer.example"])
            )
            XCTAssertEqual(merged.xcmConfig?.xcmVersion, "V3")

            let normalized = try XCTUnwrap(
                chainsByIdentifier["normalized-chain"]
            )
            XCTAssertEqual(
                normalized.selectedNode?.url,
                normalizedSelectedURL
            )
        }

        let repository = factory.createRepository()
        let fetchOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        queue.addOperations([fetchOperation], waitUntilFinished: true)
        let chains: [ChainModel] = try XCTUnwrap(
            fetchOperation.result
        ).get()
        XCTAssertEqual(
            Set(chains.map(\.chainId)),
            Set(["collision-chain", "normalized-chain"])
        )
    }

    func testCleanupCollisionPreservesCustomSelectionWhenDefaultRetires()
        throws {
        let facade = SubstrateStorageTestFacade()
        let chainId = "shared-node-collision"
        let sharedURL = try XCTUnwrap(
            URL(string: "wss://shared-node.example")
        )
        let replacementURL = try XCTUnwrap(
            URL(string: "wss://replacement-default.example")
        )

        try perform(in: facade.databaseService) { context in
            let canonical = CDChain(context: context)
            canonical.chainId = chainId
            canonical.name = "Canonical"
            let sharedNode = CDChainNode(context: context)
            sharedNode.url = sharedURL
            sharedNode.name = "Shared user selection"
            canonical.nodes = NSSet(object: sharedNode)

            let colliding = CDChain(context: context)
            colliding.chainId = " \(chainId) "
            colliding.name = "Canonical"
            colliding.customNodes = NSSet(object: sharedNode)
            colliding.selectedNode = sharedNode

            try context.save()
        }

        let factory = ChainRepositoryFactory(storageFacade: facade)
        let queue = OperationQueue()
        let cleanup = factory.createMalformedChainCleanupOperation()
        queue.addOperations([cleanup], waitUntilFinished: true)
        let _: Void = try XCTUnwrap(cleanup.result).get()

        let repository = factory.createRepository()
        let initialFetch = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        queue.addOperations([initialFetch], waitUntilFinished: true)
        let localChain = try XCTUnwrap(
            try XCTUnwrap(initialFetch.result)
                .get()
                .first { $0.chainId == chainId }
        )

        XCTAssertEqual(localChain.customNodes?.first?.url, sharedURL)
        XCTAssertEqual(
            localChain.customNodes?.first?.name,
            "Shared user selection"
        )
        XCTAssertEqual(localChain.selectedNode?.url, sharedURL)

        let replacementDefault = ChainNodeModel(
            url: replacementURL,
            name: "Replacement default",
            apikey: nil
        )
        let remoteChain = localChain.replacingNodeConfiguration(
            nodes: [replacementDefault],
            selectedNode: nil,
            customNodes: nil
        )
        let mergedChain = try XCTUnwrap(
            ChainSyncService.preservingLocalNodePreferences(
                remoteChains: [remoteChain],
                localChains: [localChain]
            ).first
        )

        XCTAssertEqual(mergedChain.nodes, Set([replacementDefault]))
        XCTAssertEqual(mergedChain.customNodes?.first?.url, sharedURL)
        XCTAssertEqual(mergedChain.selectedNode?.url, sharedURL)

        try perform(in: facade.databaseService) { context in
            let request = NSFetchRequest<CDChain>(
                entityName: String(describing: CDChain.self)
            )
            let entity = try XCTUnwrap(
                try context.fetch(request).first {
                    $0.chainId == chainId
                }
            )

            try ChainModelMapper().populate(
                entity: entity,
                from: mergedChain,
                using: context
            )
            try context.save()
        }

        let finalFetch = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        queue.addOperations([finalFetch], waitUntilFinished: true)
        let refetchedChain = try XCTUnwrap(
            try XCTUnwrap(finalFetch.result)
                .get()
                .first { $0.chainId == chainId }
        )

        XCTAssertEqual(refetchedChain.nodes, Set([replacementDefault]))
        XCTAssertEqual(refetchedChain.customNodes?.first?.url, sharedURL)
        XCTAssertEqual(
            refetchedChain.customNodes?.first?.name,
            "Shared user selection"
        )
        XCTAssertEqual(refetchedChain.selectedNode?.url, sharedURL)
    }

    func testCleanupQuarantinesConflictingCollisionWithoutDeletingItsData()
        throws {
        let facade = SubstrateStorageTestFacade()
        let chainId = "conflicting-collision"
        let canonicalURL = try XCTUnwrap(
            URL(string: "wss://canonical-collision.example")
        )
        let conflictingURL = try XCTUnwrap(
            URL(string: "wss://conflicting-collision.example")
        )

        try perform(in: facade.databaseService) { context in
            let canonical = CDChain(context: context)
            canonical.chainId = chainId
            canonical.name = "Collision chain"
            let canonicalNode = CDChainNode(context: context)
            canonicalNode.url = canonicalURL
            canonicalNode.name = "Canonical selection"
            canonical.nodes = NSSet(object: canonicalNode)
            canonical.selectedNode = canonicalNode

            let conflicting = CDChain(context: context)
            conflicting.chainId = " \(chainId) "
            conflicting.name = "Collision chain"
            let conflictingNode = CDChainNode(context: context)
            conflictingNode.url = conflictingURL
            conflictingNode.name = "Conflicting selection"
            conflicting.nodes = NSSet(object: conflictingNode)
            conflicting.selectedNode = conflictingNode

            let conflictingAsset = CDAsset(context: context)
            conflictingAsset.id = "conflicting-asset"
            conflictingAsset.name = "Conflicting asset"
            conflictingAsset.symbol = "CON"
            conflictingAsset.precision = 12
            conflicting.assets = NSSet(object: conflictingAsset)

            try context.save()
        }

        let factory = ChainRepositoryFactory(storageFacade: facade)
        let queue = OperationQueue()

        for _ in 0 ..< 2 {
            let cleanup = factory.createMalformedChainCleanupOperation()
            queue.addOperations([cleanup], waitUntilFinished: true)
            let _: Void = try XCTUnwrap(cleanup.result).get()
        }

        try perform(in: facade.databaseService) { context in
            let request = NSFetchRequest<CDChain>(
                entityName: String(describing: CDChain.self)
            )
            let chains = try context.fetch(request)
            XCTAssertEqual(chains.count, 2)

            let canonical = try XCTUnwrap(
                chains.first { $0.chainId == chainId }
            )
            XCTAssertFalse(canonical.disabled)
            XCTAssertEqual(canonical.selectedNode?.url, canonicalURL)
            XCTAssertEqual(
                Set(
                    (canonical.nodes?.allObjects as? [CDChainNode] ?? [])
                        .compactMap(\.url)
                ),
                Set([canonicalURL])
            )
            XCTAssertTrue(canonical.assets?.allObjects.isEmpty ?? true)

            let quarantined = try XCTUnwrap(
                chains.first {
                    $0.chainId?.hasPrefix(
                        ChainModelMapper
                            .quarantinedChainIdentifierPrefix
                    ) == true
                }
            )
            XCTAssertTrue(quarantined.disabled)
            XCTAssertEqual(quarantined.name, "Collision chain")
            XCTAssertEqual(quarantined.selectedNode?.url, conflictingURL)
            XCTAssertEqual(
                Set(
                    (
                        quarantined.nodes?.allObjects
                            as? [CDChainNode] ?? []
                    )
                    .compactMap(\.url)
                ),
                Set([conflictingURL])
            )
            XCTAssertEqual(
                Set(
                    (quarantined.assets?.allObjects as? [CDAsset] ?? [])
                        .compactMap(\.id)
                ),
                Set(["conflicting-asset"])
            )
        }
    }

    private func makeNode(from entity: CDChainNode) throws -> ChainNodeModel {
        ChainNodeModel(
            url: try XCTUnwrap(entity.url),
            name: try XCTUnwrap(entity.name),
            apikey: nil
        )
    }

    private func makeAssetWithUnmatchedPricing(
        identifier: String
    ) -> AssetModel {
        AssetModel(
            id: identifier,
            name: "Cached price fixture",
            symbol: "CPF",
            precision: 12,
            currencyId: "asset-currency",
            isUtility: false,
            isNative: false,
            coingeckoPriceId: "asset-price"
        )
    }

    private func makeCachedPrice(
        currencyId: String,
        priceId: String,
        price: String,
        fiatDayChange: String,
        in context: NSManagedObjectContext
    ) -> CDPriceData {
        let entity = CDPriceData(context: context)
        entity.currencyId = currencyId
        entity.priceId = priceId
        entity.price = price
        entity.fiatDayByChange = fiatDayChange
        return entity
    }

    private func makeValidChainEntity(
        in context: NSManagedObjectContext
    ) -> CDChain {
        let entity = CDChain(context: context)
        entity.chainId = "valid-chain"
        entity.name = "Valid Chain"
        return entity
    }

    private func makeCachedPriceEntity(
        managedObjectClass: AnyClass,
        priceType: NSAttributeType
    ) -> (
        model: NSManagedObjectModel,
        entity: NSEntityDescription
    ) {
        let entity = NSEntityDescription()
        entity.name = "CachedPriceFixture_" + UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
        entity.managedObjectClassName = NSStringFromClass(
            managedObjectClass
        )
        entity.properties = [
            makeAttribute(
                name: "currencyId",
                type: .stringAttributeType
            ),
            makeAttribute(
                name: "priceId",
                type: .stringAttributeType
            ),
            makeAttribute(name: "price", type: priceType)
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return (model, entity)
    }

    private func makeEntityDescription(
        managedObjectClass: AnyClass,
        properties: [NSPropertyDescription]
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "MapperExceptionFixture_" + UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
        entity.managedObjectClassName = NSStringFromClass(
            managedObjectClass
        )
        entity.properties = properties
        return entity
    }

    private func makeAttribute(
        name: String,
        type: NSAttributeType
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }

    private func makeContext(
        entities: [NSEntityDescription]
    ) throws -> NSManagedObjectContext {
        let model = NSManagedObjectModel()
        model.entities = entities
        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )
        let context = NSManagedObjectContext(
            concurrencyType: .mainQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator
        return context
    }

    private func createContext() throws -> NSManagedObjectContext {
        let modelURL = try XCTUnwrap(
            Bundle.main.url(
                forResource: "SubstrateDataModel",
                withExtension: "momd"
            )
        )
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    private func perform(
        in service: CoreDataServiceProtocol,
        _ closure: @escaping (NSManagedObjectContext) throws -> Void
    ) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Void, Error>?

        service.performAsync { context, error in
            defer { semaphore.signal() }

            do {
                if let error {
                    throw error
                }

                try closure(
                    XCTUnwrap(context, "Expected a Core Data context")
                )
                result = .success(())
            } catch {
                result = .failure(error)
            }
        }

        semaphore.wait()
        try XCTUnwrap(result).get()
    }
}

private final class ExceptionRaisingCachedPrice: NSManagedObject {
    override func willAccessValue(forKey key: String?) {
        guard key == "price" else {
            super.willAccessValue(forKey: key)
            return
        }

        NSException(
            name: .invalidArgumentException,
            reason: "adversarial cached-price row",
            userInfo: nil
        ).raise()
    }
}

private final class ChainCleanupFixtureCoreDataService:
    CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        configuration = CoreDataServiceConfiguration(
            modelURL: URL(
                fileURLWithPath:
                "/dev/null/ChainCleanupFixture.mom"
            ),
            storageType: .inMemory
        )
    }

    func performAsync(
        block: @escaping CoreDataContextInvocationBlock
    ) {
        context.perform {
            block(self.context, nil)
        }
    }

    func close() throws {}

    func drop() throws {}
}

private final class ChainCleanupFixtureStorageFacade:
    StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init(context: NSManagedObjectContext) {
        databaseService =
            ChainCleanupFixtureCoreDataService(
                context: context
            )
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U>
        where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
