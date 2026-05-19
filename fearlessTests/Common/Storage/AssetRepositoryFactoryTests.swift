import XCTest
@testable import fearless
import RobinHood
import SSFModels
import CoreData

final class AssetRepositoryFactoryTests: XCTestCase {
    func testAssetModelCompatibilityIdentifierMatchesModelId() {
        let model = AssetModel(
            id: "asset-id",
            name: "Asset",
            symbol: "AST",
            precision: 12,
            isUtility: false,
            isNative: true
        )

        XCTAssertEqual(model.identifier, model.id)
    }

    func testCreateRepositoryForwardsFilterSortAndModelEntityTypes() {
        let storageFacade = StorageFacadeSpy()
        let factory = AssetRepositoryFactory(storageFacade: storageFacade)
        let filter = NSPredicate(format: "isUtility == YES")
        let sortDescriptors = [NSSortDescriptor(key: "symbol", ascending: true)]

        _ = factory.createRepository(for: filter, sortDescriptors: sortDescriptors)

        XCTAssertEqual(storageFacade.createRepositoryInvocations, 1)
        XCTAssertTrue(storageFacade.lastFilter == filter)
        XCTAssertEqual(storageFacade.lastSortDescriptors, sortDescriptors)
        XCTAssertEqual(storageFacade.lastModelType, String(reflecting: AssetModel.self))
        XCTAssertEqual(storageFacade.lastEntityType, String(reflecting: CDAsset.self))
    }

    func testCreateAsyncRepositoryForwardsFilterSortAndModelEntityTypes() {
        let storageFacade = StorageFacadeSpy()
        let factory = AssetRepositoryFactory(storageFacade: storageFacade)
        let filter = NSPredicate(format: "isNative == YES")
        let sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]

        _ = factory.createAsyncRepository(for: filter, sortDescriptors: sortDescriptors)

        XCTAssertEqual(storageFacade.createAsyncRepositoryInvocations, 1)
        XCTAssertTrue(storageFacade.lastFilter == filter)
        XCTAssertEqual(storageFacade.lastSortDescriptors, sortDescriptors)
        XCTAssertEqual(storageFacade.lastModelType, String(reflecting: AssetModel.self))
        XCTAssertEqual(storageFacade.lastEntityType, String(reflecting: CDAsset.self))
    }
}

private final class StorageFacadeSpy: StorageFacadeProtocol {
    private let backingFacade = SubstrateStorageTestFacade()

    var databaseService: CoreDataServiceProtocol { backingFacade.databaseService }
    var createRepositoryInvocations: Int = 0
    var createAsyncRepositoryInvocations: Int = 0
    var lastFilter: NSPredicate?
    var lastSortDescriptors: [NSSortDescriptor] = []
    var lastModelType: String?
    var lastEntityType: String?

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        createRepositoryInvocations += 1
        lastFilter = filter
        lastSortDescriptors = sortDescriptors
        lastModelType = String(reflecting: T.self)
        lastEntityType = String(reflecting: U.self)

        return backingFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: mapper
        )
    }

    func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        createAsyncRepositoryInvocations += 1
        lastFilter = filter
        lastSortDescriptors = sortDescriptors
        lastModelType = String(reflecting: T.self)
        lastEntityType = String(reflecting: U.self)

        return backingFacade.createAsyncRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: mapper
        )
    }
}
