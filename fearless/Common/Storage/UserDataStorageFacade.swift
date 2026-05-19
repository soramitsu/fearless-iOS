import Foundation
import RobinHood
import CoreData

enum UserStorageParams {
    static let modelVersion: UserStorageVersion = .version12
    static let modelDirectory: String = "Modules_SSFAccountManagmentStorage.bundle//UserDataModel.momd"
    static let databaseName = "UserDataModel.sqlite"

    static let storageDirectoryURL: URL = {
        let baseURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("CoreData")

        return baseURL!
    }()

    static var storageURL: URL {
        storageDirectoryURL.appendingPathComponent(databaseName)
    }
}

class UserDataStorageFacade: StorageFacadeProtocol {
    static let shared = UserDataStorageFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let modelName = UserStorageParams.modelVersion.rawValue
        let bundle = Bundle.main

        let omoURL = bundle.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: UserStorageParams.modelDirectory
        )

        let momURL = bundle.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: UserStorageParams.modelDirectory
        )

        let modelURL = omoURL ?? momURL

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: UserStorageParams.storageDirectoryURL,
            databaseName: UserStorageParams.databaseName,
            incompatibleModelStrategy: .ignore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL!,
            storageType: .persistent(settings: persistentSettings)
        )

        databaseService = CoreDataService(configuration: configuration)

        #if DEBUG
            Logger.shared.debug("User Storage URL: \(UserStorageParams.storageURL)")
        #endif
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
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
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    func createStreamableProvider<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> StreamableProvider<T> {
        let repository = createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: mapper
        )

        let observer = CoreDataContextObservable(
            service: databaseService,
            mapper: repository.dataMapper,
            predicate: { _ in true }
        )

        observer.start { error in
            if let error = error {
                Logger.shared.error("UserDataStorage database observer unexpectedly failed: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<T>()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observer),
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}

// MARK: - Repository Async Helpers

import RobinHood

private enum RepositoryAsyncContext {
    static let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "io.fearless.repository.async"
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 2
        return q
    }()
}

extension AnyDataProviderRepository {
    func fetchAllAsync(
        options: RepositoryFetchOptions = RepositoryFetchOptions()
    ) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let op = fetchAllOperation(with: options)
            op.completionBlock = {
                do {
                    let result = try op.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            RepositoryAsyncContext.queue.addOperation(op)
        }
    }

    func fetchAsync(
        by id: @escaping @autoclosure () -> String,
        options: RepositoryFetchOptions = RepositoryFetchOptions()
    ) async throws -> T? {
        try await withCheckedThrowingContinuation { continuation in
            let op = fetchOperation(by: { id() }, options: options)
            op.completionBlock = {
                do {
                    let result = try op.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            RepositoryAsyncContext.queue.addOperation(op)
        }
    }

    func fetchAsync(
        slice: RepositorySliceRequest,
        options: RepositoryFetchOptions = RepositoryFetchOptions()
    ) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let op = fetchOperation(by: slice, options: options)
            op.completionBlock = {
                do {
                    let result = try op.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            RepositoryAsyncContext.queue.addOperation(op)
        }
    }

    func saveAsync(
        insert: @escaping @autoclosure () -> [T],
        deleteIds: @escaping @autoclosure () -> [String]
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let insertBlock: () throws -> [T] = { insert() }
            let deleteIdsBlock: () throws -> [String] = { deleteIds() }
            let op = saveOperation(insertBlock, deleteIdsBlock)
            op.completionBlock = {
                if case let .failure(error) = op.result {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
            RepositoryAsyncContext.queue.addOperation(op)
        }
    }

    func saveAsync(
        insert: @escaping @autoclosure () -> [T],
        delete: @escaping @autoclosure () -> [T]
    ) async throws {
        try await saveAsync(insert: insert(), deleteIds: delete().map(\.identifier))
    }
}
