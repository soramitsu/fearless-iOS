import UIKit
import SoraFoundation
import SSFModels
import SSFNetwork

final class CrossChainTxTrackingAssembly {
    static func configureModule(transaction: AssetTransactionData, chainAsset: ChainAsset, wallet: MetaAccountModel) -> CrossChainTxTrackingModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let networkWorker = NetworkWorkerImpl()
        let okxRequestSigner = OKXDexRequestSigner()
        let okxService = OKXDexAggregatorServiceImpl(
            networkWorker: networkWorker,
            signer: okxRequestSigner
        )
        let chainRepository = ChainRepositoryFactory().createAsyncRepository()
        let interactor = CrossChainTxTrackingInteractor(
            txHash: transaction.transactionId,
            chainAsset: chainAsset,
            okxService: okxService,
            chainRepository: chainRepository
        )
        let router = CrossChainTxTrackingRouter()

        let viewModelFactory = CrossChainTxTrackingViewModelFactoryImpl()
        let presenter = CrossChainTxTrackingPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            wallet: wallet,
            transaction: transaction
        )

        let view = CrossChainTxTrackingViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
