import Foundation
import SoraFoundation
import RobinHood
import SSFModels

final class AddERC20TokenAssembly {
    static func configureModule(
        with chain: ChainModel
    ) -> AddERC20TokenModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let storage = AnyDataProviderRepository(chainRepository)
        
        let router = AddERC20TokenRouter(localizationManager: localizationManager)
        let interactor = AddERC20TokenInteractor(
            chain: chain,
            storage: storage,
            operationManager: OperationManagerFacade.sharedManager
        )
        let presenter = AddERC20TokenPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            localizationManager: localizationManager
        )
        
        let view = AddERC20TokenViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
} 
