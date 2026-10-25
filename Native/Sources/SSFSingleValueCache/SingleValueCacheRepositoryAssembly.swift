import Foundation
import RobinHood

public typealias AsyncSingleValueRepository = AsyncCoreDataRepositoryDefault<
    SingleValueProviderObject,
    CDSingleValue
>
public typealias SingleValueRepository = CoreDataRepository<
    SingleValueProviderObject,
    CDSingleValue
>

public protocol SingleValueCacheRepositoryAssembly {
    func createSingleValueCacheRepository() -> SingleValueRepository
    func createAsyncSingleValueCacheRepository() -> AsyncSingleValueRepository
}

public final class SingleValueCacheRepositoryFactoryDefault: SingleValueCacheRepositoryAssembly {
    public init() {}

    public func createAsyncSingleValueCacheRepository() -> AsyncSingleValueRepository {
        let facade = CacheStorageFacade()
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<
            SingleValueProviderObject,
            CDSingleValue
        >())
        let repository = facade.createAsyncRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: mapper
        )
        return repository
    }

    public func createSingleValueCacheRepository() -> SingleValueRepository {
        let facade = CacheStorageFacade()
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<
            SingleValueProviderObject,
            CDSingleValue
        >())
        let repository = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: mapper
        )
        return repository
    }
}
