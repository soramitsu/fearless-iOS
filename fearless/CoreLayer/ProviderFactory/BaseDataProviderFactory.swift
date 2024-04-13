import RobinHood
import SSFSingleValueCache

class BaseDataProviderFactory {
    func createSingleValueCache()
        throws -> CoreDataRepository<SingleValueProviderObject, CDSingleValue> {
        try SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
    }
}
