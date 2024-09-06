import UIKit
import SoraFoundation
import SSFModels
import SSFNetwork

final class CrossChainSwapSetupAssembly {
    static func configureModule(wallet: MetaAccountModel, chainAsset: ChainAsset) -> CrossChainSwapSetupModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )
        let networkWorker = NetworkWorkerImpl()
        let okxService = OKXDexAggregatorServiceImpl(networkWorker: networkWorker, signer: OKXDexRequestSigner())
        let interactor = CrossChainSwapSetupInteractor(okxService: okxService, wallet: wallet, accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter)
        let router = CrossChainSwapSetupRouter()

        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = CrossChainSwapSetupPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: CrossChainSwapSetupViewModelFactoryImpl(),
            wallet: wallet,
            chainAsset: chainAsset,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = CrossChainSwapSetupViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
