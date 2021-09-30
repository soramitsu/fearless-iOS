import Foundation
import RobinHood

final class ChainRepositoryFactory {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    func createRepository(
        for filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) -> AnyDataProviderRepository<ChainModel> {
        let mapper = ChainModelMapper()
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
