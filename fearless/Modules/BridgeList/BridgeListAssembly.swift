import UIKit
import SoraFoundation
import SSFModels
import SSFNetwork

final class BridgeListAssembly {
    static func configureModule(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        moduleOutput: BridgeListModuleOutput?,
        selectedSort: UInt8
    ) -> BridgeListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let networkWorker = NetworkWorkerImpl()
        let requestSigner = OKXDexRequestSigner()
        let okxService = OKXDexAggregatorServiceImpl(
            networkWorker: networkWorker,
            signer: requestSigner
        )
        let interactor = BridgeListInteractor(
            okxService: okxService,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            wallet: wallet
        )
        let router = BridgeListRouter()

        let presenter = BridgeListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            viewModelFactory: BridgeListViewModelFactoryImpl(wallet: wallet),
            selectedSort: selectedSort
        )

        let view = BridgeListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        presenter.moduleOutput = moduleOutput

        return (view, presenter)
    }
}
