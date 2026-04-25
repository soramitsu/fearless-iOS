import XCTest
@testable import fearless
import RobinHood
import SSFModels
import CoreData

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
