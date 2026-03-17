import Foundation
import RobinHood
import SSFUtils
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

final class ScamSyncServiceFactory {
    static func createService() -> ScamSyncServiceProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared
        let mapper: CodableCoreDataMapper<ScamInfo, SSFAssetManagmentStorage.CDScamInfo> =
            // Use a literal to avoid module-qualified #keyPath limitation
            CodableCoreDataMapper(entityIdentifierFieldName: "address")

        let repository: CoreDataRepository<ScamInfo, SSFAssetManagmentStorage.CDScamInfo> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let service = ScamSyncService(
            scamListCsvURL: ApplicationConfig.shared.scamListCsvURL,
            repository: AnyDataProviderRepository(repository),
            dataFetchFactory: DataOperationFactory(),
            retryStrategy: ExponentialReconnection(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return service
    }
}
