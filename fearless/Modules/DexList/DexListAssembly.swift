import UIKit
import SoraFoundation
import SSFModels
import SSFNetwork

final class DexListAssembly {
    static func configureModule(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        moduleOutput: DexListModuleOutput?,
        selectedDexIds: [String]?
    ) -> DexListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let networkWorker = NetworkWorkerImpl()
        let requestSigner = OKXDexRequestSigner()
        let okxService = OKXDexAggregatorServiceImpl(
            networkWorker: networkWorker,
            signer: requestSigner
        )
        let interactor = DexListInteractor(
            okxService: okxService,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            wallet: wallet
        )
        let router = DexListRouter()

        let presenter = DexListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            viewModelFactory: DexListViewModelFactoryImpl(wallet: wallet),
            selectedDexIds: selectedDexIds
        )

        let view = DexListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        presenter.moduleOutput = moduleOutput

        return (view, presenter)
    }
}
