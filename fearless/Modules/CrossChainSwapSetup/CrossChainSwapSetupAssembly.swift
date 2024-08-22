import UIKit
import SoraFoundation
import SSFModels
import SSFNetwork

final class CrossChainSwapSetupAssembly {
    static func configureModule(wallet: MetaAccountModel, chainAsset: ChainAsset) -> CrossChainSwapSetupModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let networkWorker = NetworkWorkerImpl()
        let okxService = OKXDexAggregatorServiceImpl(networkWorker: networkWorker, signer: OKXDexRequestSigner())
        let interactor = CrossChainSwapSetupInteractor(okxService: okxService, wallet: wallet)
        let router = CrossChainSwapSetupRouter()

        let presenter = CrossChainSwapSetupPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: CrossChainSwapSetupViewModelFactoryImpl(),
            wallet: wallet,
            chainAsset: chainAsset
        )

        let view = CrossChainSwapSetupViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
