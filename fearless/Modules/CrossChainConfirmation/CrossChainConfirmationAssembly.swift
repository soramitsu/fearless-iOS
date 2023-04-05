import Foundation
import SoraFoundation
import RobinHood

final class CrossChainConfirmationAssembly {
    static func configureModule(
        with data: CrossChainConfirmationData
    ) -> CrossChainConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let depsContainer = CrossChainDepsContainer(
            wallet: data.wallet,
            chainsTypesMap: chainRegistry.chainsTypesMap
        )
        let runtimeMetadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let interactor = CrossChainConfirmationInteractor(
            teleportData: data,
            depsContainer: depsContainer,
            runtimeItemRepository: AnyDataProviderRepository(runtimeMetadataRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
        let router = CrossChainConfirmationRouter()

        let presenter = CrossChainConfirmationPresenter(
            teleportData: data,
            viewModelFactory: CrossChainConfirmationViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = CrossChainConfirmationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
