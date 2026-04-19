import XCTest
@testable import fearless
import RobinHood
import SSFModels
import CoreData

class MetaAccountMapperTests: XCTestCase {
    func testSaveAndFetch() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let maxChainAccountCount = 3
        let accountCount = 10

        let metaAccounts: [fearless.ManagedMetaAccountModel] = (0..<accountCount).map { _ in
            let account = AccountGenerator.generateMetaAccount(
                generatingChainAccounts: (0..<maxChainAccountCount).randomElement()!
            )

            return fearless.ManagedMetaAccountModel(
                info: account,
                isSelected: false,
                order: fearless.ManagedMetaAccountModel.noOrder
            )
        }

        // when

        let saveOperation = repository.saveOperation( { metaAccounts }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // then

        let allMetaAccountsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        let expectedAccounts = metaAccounts.reduce(into: [String: MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        let actualAccounts = allMetaAccounts.reduce(into: [String: MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        let differentOrders = allMetaAccounts.reduce(into: Set<UInt32>()) { $0.insert($1.order) }

        XCTAssertEqual(expectedAccounts, actualAccounts)
        XCTAssertEqual(differentOrders.count, accountCount)
    }

}

final class AssetModelMapperTests: XCTestCase {
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

    private func createAssetContext() throws -> NSManagedObjectContext {
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

        assetEntity.properties = [
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
            makeAttribute(name: "purchaseProviders", type: .transformableAttributeType),
            priceProviderRelationship
        ]

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
}
