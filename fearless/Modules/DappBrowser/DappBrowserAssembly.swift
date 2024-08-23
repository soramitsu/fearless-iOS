import UIKit
import SoraFoundation
import RobinHood
import SSFSingleValueCache
import SSFModels

final class DappBrowserAssembly {
    static func configureModule(
        wallet: MetaAccountModel
    ) -> DappBrowserModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = DappBrowserInteractor(
            dappProvider: createProvider(),
            appRepository: ServiceAssembly.shared.tonConnectAppAsyncRepository(), 
            chainsRepository: ServiceAssembly.shared.asyncChainModelRepository(sortDescriptors: []), 
            filterStorage: ServiceAssembly.shared.userDefaults
        )
        let router = DappBrowserRouter()

        let presenter = DappBrowserPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            logger: ServiceAssembly.shared.logger,
            viewModelFactory: DappBrowserViewModelFactoryImpl(), 
            wallet: wallet
        )

        let view = DappBrowserViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    private static func createProvider() -> AnySingleValueProvider<[DappCategory]> {
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
        let source = DappDataSource()
        let trigger: DataProviderEventTrigger = [.onFetchPage, .onAll]
        let provider = SingleValueProvider(
            targetIdentifier: "dapp.remote.target.identifier",
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger,
            executionQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return AnySingleValueProvider(provider)
    }
}
