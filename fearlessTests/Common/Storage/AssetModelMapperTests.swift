import XCTest
@testable import fearless
import RobinHood
import SSFModels
import CoreData
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

final class AssetModelMapperTests: XCTestCase {
    func testEntityIdentifierFieldNameUsesCoreDataAssetIdField() {
        let mapper = AssetModelMapper()

        XCTAssertEqual(mapper.entityIdentifierFieldName, "id")
    }

    func testTransformThrowsWhenIdentifierMissing() throws {
        let mapper = AssetModelMapper()
        let context = try createAssetContext()

        let entity = CDAsset(context: context)
        entity.symbol = "DOT"
        entity.name = "Polkadot"

        XCTAssertThrowsError(try mapper.transform(entity: entity)) { error in
            guard case AssetModelMapperError.missedRequiredFields = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testTransformUsesIdentifierAsSymbolAndNameFallback() throws {
        let mapper = AssetModelMapper()
        let context = try createAssetContext()

        let entity = CDAsset(context: context)
        entity.id = "asset-id"
        entity.symbol = nil
        entity.name = nil
        entity.precision = 12
        entity.isUtility = false
        entity.isNative = false

        let model = try mapper.transform(entity: entity)

        XCTAssertEqual(model.id, "asset-id")
        XCTAssertEqual(model.symbol, "asset-id")
        XCTAssertEqual(model.name, "asset-id")
    }

    func testPopulateThenTransformPreservesExtendedAssetFields() throws {
        let mapper = AssetModelMapper()
        let context = try createAssetContext(includePricingFields: true)

        let model = AssetModel(
            id: "asset-id",
            name: "Polkadot",
            symbol: "DOT",
            precision: 12,
            icon: URL(string: "https://example.com/icon.png"),
            price: Decimal(string: "12.34"),
            fiatDayChange: Decimal(string: "-0.98"),
            currencyId: "usd",
            existentialDeposit: "10000000000",
            color: "#112233",
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            purchaseProviders: [.moonpay, .ramp],
            type: .normal,
            ethereumType: .erc20,
            priceProvider: PriceProvider(type: .coingecko, id: "polkadot", precision: 4),
            coingeckoPriceId: "polkadot"
        )

        let entity = CDAsset(context: context)
        try mapper.populate(entity: entity, from: model, using: context)

        let mappedModel = try mapper.transform(entity: entity)

        XCTAssertEqual(mappedModel.id, model.id)
        XCTAssertEqual(mappedModel.name, model.name)
        XCTAssertEqual(mappedModel.symbol, model.symbol)
        XCTAssertEqual(mappedModel.precision, model.precision)
        XCTAssertEqual(mappedModel.price, model.price)
        XCTAssertEqual(mappedModel.fiatDayChange, model.fiatDayChange)
        XCTAssertEqual(mappedModel.currencyId, model.currencyId)
        XCTAssertEqual(mappedModel.existentialDeposit, model.existentialDeposit)
        XCTAssertEqual(mappedModel.color, model.color)
        XCTAssertEqual(mappedModel.isUtility, model.isUtility)
        XCTAssertEqual(mappedModel.isNative, model.isNative)
        XCTAssertEqual(mappedModel.staking, model.staking)
        XCTAssertEqual(mappedModel.purchaseProviders, model.purchaseProviders)
        XCTAssertEqual(mappedModel.type, model.type)
        XCTAssertEqual(mappedModel.ethereumType, model.ethereumType)
        XCTAssertEqual(mappedModel.priceProvider, model.priceProvider)
        XCTAssertEqual(mappedModel.coingeckoPriceId, model.coingeckoPriceId)
    }

    func testPopulateDoesNotRequireOptionalPricingFieldsInEntitySchema() throws {
        let mapper = AssetModelMapper()
        let context = try createAssetContext(includePricingFields: false)

        let model = AssetModel(
            id: "asset-id",
            name: "Polkadot",
            symbol: "DOT",
            precision: 12,
            price: Decimal(string: "1.23"),
            fiatDayChange: Decimal(string: "0.45"),
            isUtility: false,
            isNative: true
        )

        let entity = CDAsset(context: context)

        XCTAssertNoThrow(try mapper.populate(entity: entity, from: model, using: context))
    }

    func testTransformPriceProviderPrecisionUsesNilForMalformedPrecisionString() throws {
        let mapper = AssetModelMapper()
        let context = try createAssetContext()

        let priceProvider = CDPriceProvider(context: context)
        priceProvider.type = PriceProviderType.coingecko.rawValue
        priceProvider.id = "dot"
        priceProvider.precision = "not-a-number"

        let entity = CDAsset(context: context)
        entity.id = "asset-id"
        entity.symbol = "DOT"
        entity.name = "Polkadot"
        entity.precision = 12
        entity.priceProvider = priceProvider

        let model = try mapper.transform(entity: entity)

        XCTAssertEqual(model.priceProvider?.type, .coingecko)
        XCTAssertEqual(model.priceProvider?.id, "dot")
        XCTAssertNil(model.priceProvider?.precision)
    }

    func testTransformPriceProviderIsNilWhenTypeIsUnknown() throws {
        let mapper = AssetModelMapper()
        let context = try createAssetContext()

        let priceProvider = CDPriceProvider(context: context)
        priceProvider.type = "unknown-provider"
        priceProvider.id = "dot"
        priceProvider.precision = "4"

        let entity = CDAsset(context: context)
        entity.id = "asset-id"
        entity.symbol = "DOT"
        entity.name = "Polkadot"
        entity.precision = 12
        entity.priceProvider = priceProvider

        let model = try mapper.transform(entity: entity)

        XCTAssertNil(model.priceProvider)
    }

    private func createAssetContext(includePricingFields: Bool = false) throws -> NSManagedObjectContext {
        let model = NSManagedObjectModel()

        let priceProviderEntity = NSEntityDescription()
        priceProviderEntity.name = "CDPriceProvider"
        priceProviderEntity.managedObjectClassName = NSStringFromClass(CDPriceProvider.self)
        priceProviderEntity.properties = [
            makeAttribute(name: "type", type: .stringAttributeType),
            makeAttribute(name: "id", type: .stringAttributeType),
            makeAttribute(name: "precision", type: .stringAttributeType)
        ]

        let assetEntity = NSEntityDescription()
        assetEntity.name = "CDAsset"
        assetEntity.managedObjectClassName = NSStringFromClass(CDAsset.self)

        let priceProviderRelationship = NSRelationshipDescription()
        priceProviderRelationship.name = "priceProvider"
        priceProviderRelationship.destinationEntity = priceProviderEntity
        priceProviderRelationship.minCount = 0
        priceProviderRelationship.maxCount = 1
        priceProviderRelationship.deleteRule = .nullifyDeleteRule
        priceProviderRelationship.isOptional = true

        var assetProperties: [NSPropertyDescription] = [
            makeAttribute(name: "id", type: .stringAttributeType),
            makeAttribute(name: "icon", type: .URIAttributeType),
            makeAttribute(name: "precision", type: .integer16AttributeType),
            makeAttribute(name: "priceId", type: .stringAttributeType),
            makeAttribute(name: "symbol", type: .stringAttributeType),
            makeAttribute(name: "existentialDeposit", type: .stringAttributeType),
            makeAttribute(name: "color", type: .stringAttributeType),
            makeAttribute(name: "name", type: .stringAttributeType),
            makeAttribute(name: "currencyId", type: .stringAttributeType),
            makeAttribute(name: "type", type: .stringAttributeType),
            makeAttribute(name: "isUtility", type: .booleanAttributeType),
            makeAttribute(name: "isNative", type: .booleanAttributeType),
            makeAttribute(name: "staking", type: .stringAttributeType),
            makeAttribute(name: "ethereumType", type: .stringAttributeType),
            makeSecureTransformableAttribute(name: "purchaseProviders"),
            priceProviderRelationship
        ]

        if includePricingFields {
            assetProperties.append(makeAttribute(name: "price", type: .decimalAttributeType))
            assetProperties.append(makeAttribute(name: "fiatDayChange", type: .decimalAttributeType))
        }

        assetEntity.properties = assetProperties

        model.entities = [assetEntity, priceProviderEntity]

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    private func makeAttribute(name: String, type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }

    private func makeSecureTransformableAttribute(name: String) -> NSAttributeDescription {
        let attribute = makeAttribute(name: name, type: .transformableAttributeType)
        attribute.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        attribute.attributeValueClassName = NSStringFromClass(NSArray.self)
        return attribute
    }
}

final class PolkaswapSettingMapperTests: XCTestCase {
    func testEntityIdentifierFieldNameUsesVersion() {
        let mapper = PolkaswapSettingMapper()

        XCTAssertEqual(mapper.entityIdentifierFieldName, "version")
    }

    func testPopulateThenTransformPreservesRemoteSettings() throws {
        let mapper = PolkaswapSettingMapper()
        let context = try createPolkaswapSettingsContext()
        let model = PolkaswapRemoteSettings(
            version: "v2",
            availableDexIds: [
                PolkaswapDex(name: "Polkaswap", code: 0, assetId: "xor"),
                PolkaswapDex(name: "Kensetsu", code: 1, assetId: "ksm")
            ],
            availableSources: [.smart, .xyk, .tbc],
            forceSmartIds: ["xor", "xstusd"],
            xstusdId: "xstusd"
        )

        let entity = SSFAssetManagmentStorage.CDPolkaswapRemoteSettings(context: context)
        try mapper.populate(entity: entity, from: model, using: context)

        let mappedModel = try mapper.transform(entity: entity)

        XCTAssertEqual(entity.version, model.version)
        XCTAssertEqual(entity.availableSources, model.availableSources.map(\.rawValue))
        XCTAssertEqual(entity.forceSmartIds, model.forceSmartIds)
        XCTAssertEqual(entity.xstusdId, model.xstusdId)
        XCTAssertEqual(mappedModel.version, model.version)
        XCTAssertEqual(mappedModel.availableSources, model.availableSources)
        XCTAssertEqual(mappedModel.forceSmartIds, model.forceSmartIds)
        XCTAssertEqual(mappedModel.xstusdId, model.xstusdId)
        XCTAssertEqual(
            mappedModel.availableDexIds.sortedByCode().map(\.name),
            model.availableDexIds.map(\.name)
        )
        XCTAssertEqual(
            mappedModel.availableDexIds.sortedByCode().map(\.code),
            model.availableDexIds.map(\.code)
        )
        XCTAssertEqual(
            mappedModel.availableDexIds.sortedByCode().map(\.assetId),
            model.availableDexIds.map(\.assetId)
        )
    }

    func testTransformThrowsWhenRequiredFieldsAreMissing() throws {
        let mapper = PolkaswapSettingMapper()
        let context = try createPolkaswapSettingsContext()
        let entity = SSFAssetManagmentStorage.CDPolkaswapRemoteSettings(context: context)
        entity.availableSources = [LiquiditySourceType.smart.rawValue]
        entity.forceSmartIds = ["xor"]
        entity.availableDexIds = []
        entity.xstusdId = "xstusd"

        XCTAssertThrowsError(try mapper.transform(entity: entity)) { error in
            guard case PolkaswapSettingMapperError.requiredFieldsMissing = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testTransformSkipsUnknownSourcesAndMalformedDexes() throws {
        let mapper = PolkaswapSettingMapper()
        let context = try createPolkaswapSettingsContext()

        let validDex = SSFAssetManagmentStorage.CDPolkaswapDex(context: context)
        validDex.name = "Polkaswap"
        validDex.code = 0
        validDex.assetId = "xor"

        let malformedDex = SSFAssetManagmentStorage.CDPolkaswapDex(context: context)
        malformedDex.name = "MissingAsset"
        malformedDex.code = 1
        malformedDex.assetId = nil

        let entity = SSFAssetManagmentStorage.CDPolkaswapRemoteSettings(context: context)
        entity.version = "v3"
        entity.availableSources = [
            LiquiditySourceType.smart.rawValue,
            "unknown-source",
            LiquiditySourceType.xyk.rawValue
        ]
        entity.forceSmartIds = ["xor"]
        entity.availableDexIds = [validDex, malformedDex]
        entity.xstusdId = "xstusd"

        let model = try mapper.transform(entity: entity)

        XCTAssertEqual(model.availableSources, [.smart, .xyk])
        XCTAssertEqual(model.availableDexIds.map(\.name), ["Polkaswap"])
        XCTAssertEqual(model.availableDexIds.map(\.code), [0])
        XCTAssertEqual(model.availableDexIds.map(\.assetId), ["xor"])
    }

    private func createPolkaswapSettingsContext() throws -> NSManagedObjectContext {
        let model = NSManagedObjectModel()

        let settingsEntity = NSEntityDescription()
        settingsEntity.name = "CDPolkaswapRemoteSettings"
        settingsEntity.managedObjectClassName = NSStringFromClass(SSFAssetManagmentStorage.CDPolkaswapRemoteSettings.self)

        let dexEntity = NSEntityDescription()
        dexEntity.name = "CDPolkaswapDex"
        dexEntity.managedObjectClassName = NSStringFromClass(SSFAssetManagmentStorage.CDPolkaswapDex.self)
        dexEntity.properties = [
            makeAttribute(name: "name", type: .stringAttributeType),
            makeAttribute(name: "code", type: .integer32AttributeType),
            makeAttribute(name: "assetId", type: .stringAttributeType)
        ]

        let availableDexIdsRelationship = NSRelationshipDescription()
        availableDexIdsRelationship.name = "availableDexIds"
        availableDexIdsRelationship.destinationEntity = dexEntity
        availableDexIdsRelationship.minCount = 0
        availableDexIdsRelationship.maxCount = 0
        availableDexIdsRelationship.deleteRule = .cascadeDeleteRule
        availableDexIdsRelationship.isOptional = true

        settingsEntity.properties = [
            makeAttribute(name: "version", type: .stringAttributeType),
            makeSecureStringArrayAttribute(name: "availableSources"),
            makeSecureStringArrayAttribute(name: "forceSmartIds"),
            makeAttribute(name: "xstusdId", type: .stringAttributeType),
            availableDexIdsRelationship
        ]

        model.entities = [settingsEntity, dexEntity]

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    private func makeAttribute(name: String, type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }

    private func makeSecureStringArrayAttribute(name: String) -> NSAttributeDescription {
        let attribute = makeAttribute(name: name, type: .transformableAttributeType)
        attribute.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        attribute.attributeValueClassName = NSStringFromClass(NSArray.self)
        return attribute
    }
}

final class ChainSettingsMapperTests: XCTestCase {
    func testEntityIdentifierFieldNameUsesChainId() {
        let mapper = ChainSettingsMapper()

        XCTAssertEqual(mapper.entityIdentifierFieldName, "chainId")
    }

    func testPopulateThenTransformPreservesSettings() throws {
        let mapper = ChainSettingsMapper()
        let context = try createChainSettingsContext()
        let model = ChainSettings(chainId: "sora-mainnet", autobalanced: false, issueMuted: true)

        let entity = CDChainSettings(context: context)
        try mapper.populate(entity: entity, from: model, using: context)

        let mappedModel = try mapper.transform(entity: entity)

        XCTAssertEqual(mappedModel, model)
        XCTAssertEqual(entity.chainId, model.chainId)
        XCTAssertFalse(entity.autobalanced)
        XCTAssertTrue(entity.issueMuted)
    }

    func testTransformUsesFalseDefaultsWhenBooleanFieldsAreUnset() throws {
        let mapper = ChainSettingsMapper()
        let context = try createChainSettingsContext()
        let entity = CDChainSettings(context: context)
        entity.chainId = "polkadot"

        let model = try mapper.transform(entity: entity)

        XCTAssertEqual(model, ChainSettings(chainId: "polkadot", autobalanced: false, issueMuted: false))
    }

    func testTransformThrowsWhenChainIdIsMissing() throws {
        let mapper = ChainSettingsMapper()
        let context = try createChainSettingsContext()
        let entity = CDChainSettings(context: context)

        XCTAssertThrowsError(try mapper.transform(entity: entity)) { error in
            guard case ChainNodeMapperError.missedRequiredFields = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    private func createChainSettingsContext() throws -> NSManagedObjectContext {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "CDChainSettings"
        entity.managedObjectClassName = NSStringFromClass(CDChainSettings.self)
        entity.properties = [
            makeAttribute(name: "chainId", type: .stringAttributeType),
            makeAttribute(name: "autobalanced", type: .booleanAttributeType),
            makeAttribute(name: "issueMuted", type: .booleanAttributeType)
        ]

        model.entities = [entity]

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    private func makeAttribute(name: String, type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }
}

private extension Array where Element == PolkaswapDex {
    func sortedByCode() -> [PolkaswapDex] {
        sorted { $0.code < $1.code }
    }
}
