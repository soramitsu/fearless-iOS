import UIKit
import SoraFoundation
import SSFModels
import SSFNetwork

final class CrossChainSwapSetupAssembly {
    static func configureModule(wallet: MetaAccountModel, chainAsset: ChainAsset?, moduleOutput: CrossChainSwapSetupModuleOutput?) -> CrossChainSwapSetupModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let repository = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createAccountInfoStorageItemRepository()
        let ethereumBalanceRepositoryWrapper = EthereumBalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )

        let networkWorker = NetworkWorkerImpl()
        let okxService = OKXDexAggregatorServiceImpl(networkWorker: networkWorker, signer: OKXDexRequestSigner())
        let ethereumBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repositoryWrapper: ethereumBalanceRepositoryWrapper
        )

        let interactor = CrossChainSwapSetupInteractor(
            okxService: okxService,
            wallet: wallet,
            balanceFetching: ethereumBalanceFetching
        )
        let router = CrossChainSwapSetupRouter()

        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = CrossChainSwapSetupPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: CrossChainSwapSetupViewModelFactoryImpl(),
            wallet: wallet,
            chainAsset: chainAsset,
            dataValidatingFactory: dataValidatingFactory,
            moduleOutput: moduleOutput
        )

        let view = CrossChainSwapSetupViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
