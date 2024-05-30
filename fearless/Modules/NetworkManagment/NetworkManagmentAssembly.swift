import UIKit
import SoraFoundation
import RobinHood
import SSFModels

final class NetworkManagmentAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chains: [ChainModel]?,
        contextTag: Int?,
        moduleOutput: NetworkManagmentModuleOutput?
    ) -> NetworkManagmentModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = NetworkManagmentInteractor(
            wallet: wallet,
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            chainModels: chains,
            eventCenter: EventCenter.shared
        )
        let router = NetworkManagmentRouter()

        let presenter = NetworkManagmentPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            moduleOutput: moduleOutput,
            logger: Logger.shared,
            viewModelFactory: NetworkManagmentViewModelFactoryImpl(),
            contextTag: contextTag,
            localizationManager: localizationManager
        )

        let view = NetworkManagmentViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
