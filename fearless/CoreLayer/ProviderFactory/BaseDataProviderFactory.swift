import RobinHood
import SSFSingleValueCache

class BaseDataProviderFactory {
    func createSingleValueCache() -> CoreDataRepository<SingleValueProviderObject, CDSingleValue> {
        SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
    }
}
