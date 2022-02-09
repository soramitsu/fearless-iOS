import CommonWallet
import RobinHood

class BaseDataProviderFactory {
    let cacheFacade: StorageFacadeProtocol

    init(cacheFacade: StorageFacadeProtocol) {
        self.cacheFacade = cacheFacade
    }

    func createSingleValueCache()
        -> CoreDataRepository<SingleValueProviderObject, CDSingleValue> {
        cacheFacade.createRepository()
    }
}
