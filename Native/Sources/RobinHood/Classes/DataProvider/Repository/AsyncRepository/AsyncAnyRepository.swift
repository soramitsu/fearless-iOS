import Foundation

 public final class AsyncAnyRepository<T: Identifiable>: AsyncCoreDataRepository {
     public typealias Model = T

     private let _save: ([Model], [String]) async -> Void
     private let _fetchAll: (RepositoryFetchOptions) async throws -> [Model]
     private let _fetchByModelIds: ([String], RepositoryFetchOptions) async throws -> [Model]
     private let _fetchByModelId: (String, RepositoryFetchOptions) async throws -> Model?

     public init<U: AsyncCoreDataRepository>(_ repository: U) where U.Model == Model {
         _save = repository.save
         _fetchAll = repository.fetchAll
         _fetchByModelIds = repository.fetch
         _fetchByModelId = repository.fetch
     }

     public func save(models: [T], deleteIds: [String]) async where T == Model{
         await _save(models, deleteIds)
     }

     public func fetchAll(with options: RepositoryFetchOptions) async throws -> [T] {
         try await _fetchAll(options)
     }

     public func fetch(by modelId: String, options: RepositoryFetchOptions) async throws -> T? {
         try await _fetchByModelId(modelId, options)
     }

     public func fetch(by modelIds: [String], options: RepositoryFetchOptions) async throws -> [T] {
         try await _fetchByModelIds(modelIds, options)
     }
 }
