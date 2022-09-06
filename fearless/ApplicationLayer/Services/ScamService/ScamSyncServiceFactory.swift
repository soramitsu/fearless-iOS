import Foundation
import RobinHood
import FearlessUtils

final class ScamSyncServiceFactory {
    static func createService() -> ScamSyncServiceProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared
        let mapper: CodableCoreDataMapper<ScamInfo, CDScamInfo> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDScamInfo.address))

        let repository: CoreDataRepository<ScamInfo, CDScamInfo> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let service = ScamSyncService(
            scamListCsvURL: ApplicationConfig.shared.scamUrl,
            repository: AnyDataProviderRepository(repository),
            dataFetchFactory: DataOperationFactory(),
            retryStrategy: ExponentialReconnection(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return service
    }
}
