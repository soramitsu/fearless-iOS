import Foundation
@testable import fearless
import RobinHood
import CoreData

private final class TestCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol

    private let lock = NSLock()
    private var context: NSManagedObjectContext?
    private let managedObjectClassNames: [String: String]

    init(modelURL: URL, managedObjectClassNames: [String: String]) {
        configuration = CoreDataServiceConfiguration(modelURL: modelURL, storageType: .inMemory)
        self.managedObjectClassNames = managedObjectClassNames
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        lock.lock()

        do {
            let context = try self.context ?? setup()
            lock.unlock()

            context.perform {
                block(context, nil)
            }
        } catch {
            lock.unlock()
            block(nil, error)
        }
    }

    func close() throws {
        lock.lock()
        context = nil
        lock.unlock()
    }

    func drop() throws {}

    private func setup() throws -> NSManagedObjectContext {
        guard let model = NSManagedObjectModel(contentsOf: configuration.modelURL) else {
            throw CoreDataServiceError.modelInitializationFailed
        }

        qualifyManagedObjectClasses(for: model)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        self.context = context

        return context
    }

    private func qualifyManagedObjectClasses(for model: NSManagedObjectModel) {
        model.entities.forEach(qualifyManagedObjectClass)
    }

    private func qualifyManagedObjectClass(for entity: NSEntityDescription) {
        guard let entityName = entity.name else {
            return
        }

        if let className = managedObjectClassNames[entityName] {
            entity.managedObjectClassName = className
        }

        entity.subentities.forEach(qualifyManagedObjectClass)
    }
}

class UserDataStorageTestFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init() {
        let modelName = UserStorageParams.modelVersion.rawValue
        let subdirectory = UserStorageParams.modelDirectory
        let bundle = Bundle(for: UserDataStorageFacade.self)

        let omoURL = bundle.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: subdirectory
        )

        let momURL = bundle.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: subdirectory
        )

        let mainOmoURL = Bundle.main.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: subdirectory
        )

        let mainMomURL = Bundle.main.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: subdirectory
        )

        let modelURL = omoURL ?? momURL ?? mainOmoURL ?? mainMomURL

        let managedObjectClassNames: [String: String] = [
            "CDAccountInfo": NSStringFromClass(CDAccountInfo.self),
            "CDAssetVisibility": NSStringFromClass(CDAssetVisibility.self),
            "CDChainAccount": NSStringFromClass(CDChainAccount.self),
            "CDChainSettings": NSStringFromClass(CDChainSettings.self),
            "CDCurrency": NSStringFromClass(CDCurrency.self),
            "CDCustomChainNode": NSStringFromClass(CDCustomChainNode.self),
            "CDMetaAccount": NSStringFromClass(CDMetaAccount.self)
        ]

        databaseService = TestCoreDataService(
            modelURL: modelURL!,
            managedObjectClassNames: managedObjectClassNames
        )
    }

    func createRepository<T, U>(filter: NSPredicate?,
                            sortDescriptors: [NSSortDescriptor],
                            mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable, U: NSManagedObject {
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper, filter: filter,
                                      sortDescriptors: sortDescriptors)
    }

    func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
