import Foundation
import RobinHood
import SSFModels

final class AssetRepositoryFactory {
    let storageFacade: StorageFacadeProtocol
    private let mapper: AnyCoreDataMapper<AssetModel, CDAsset>

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
        mapper = AnyCoreDataMapper(AssetModelMapper())
    }

    func createRepository(
        for filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) -> CoreDataRepository<AssetModel, CDAsset> {
        storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: mapper
        )
    }

    func createAsyncRepository(
        for filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) -> AsyncCoreDataRepositoryDefault<AssetModel, CDAsset> {
        storageFacade.createAsyncRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: mapper
        )
    }
}
