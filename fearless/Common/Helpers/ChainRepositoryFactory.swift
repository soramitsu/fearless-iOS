import Foundation
import RobinHood
import SSFModels

final class ChainRepositoryFactory {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    func createRepository(
        for filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) -> CoreDataRepository<ChainModel, CDChain> {
        let mapper = ChainModelMapper()
        return storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )
    }
}
