import Foundation
import SoraFoundation
import RobinHood
import SSFModels
import SSFNetwork

final class AddERC20TokenAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        moduleOutput: AddERC20TokenModuleOutput?
    ) -> AddERC20TokenModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let storage = AnyDataProviderRepository(chainRepository)
        
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: storage,
            operationQueue: operationQueue
        )
        
        let router = AddERC20TokenRouter(localizationManager: localizationManager)
        let interactor = AddERC20TokenInteractor(
            storage: storage,
            operationManager: OperationManagerFacade.sharedManager,
            ethereumNodeFetching: EthereumNodeFetching(),
            chainAssetFetching: chainAssetFetching
        )
        let presenter = AddERC20TokenPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            localizationManager: localizationManager,
            moduleOutput: moduleOutput
        )
        
        let view = AddERC20TokenViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        
        return (view, presenter)
    }
}
