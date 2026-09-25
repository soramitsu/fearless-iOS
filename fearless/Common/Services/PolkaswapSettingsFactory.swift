import Foundation
import RobinHood
import SSFUtils
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

final class PolkaswapSettingsFactory {
    static func bundledSettings(bundle: Bundle = .main) -> PolkaswapRemoteSettings? {
        guard let url = bundle.url(forResource: "polkaswapSettings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(PolkaswapRemoteSettings.self, from: data),
              !settings.availableDexIds.isEmpty,
              Set(settings.availableDexIds.map(\.code)).count == settings.availableDexIds.count,
              !settings.xstusdId.isEmpty
        else {
            return nil
        }

        return settings
    }

    static func createService() -> PolkaswapSettingsSyncServiceProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared

        let mapper = PolkaswapSettingMapper()

        let repository: CoreDataRepository<PolkaswapRemoteSettings, SSFAssetManagmentStorage.CDPolkaswapRemoteSettings>
            = repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let service = PolkaswapSettingsSyncService(
            settingsUrl: ApplicationConfig.shared.polkaswapSettingsURL,
            dataFetchFactory: DataOperationFactory(),
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return service
    }
}
