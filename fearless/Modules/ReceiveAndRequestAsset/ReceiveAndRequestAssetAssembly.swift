import UIKit
import SoraFoundation
import SSFModels

final class ReceiveAndRequestAssetAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> ReceiveAndRequestAssetModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let repositoryFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: repositoryFacade
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let interactor = ReceiveAndRequestAssetInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            chainAsset: chainAsset
        )
        let router = ReceiveAndRequestAssetRouter()

        let qrService = QRService(
            operationFactory: QROperationFactory(),
            encoder: QREncoder()
        )
        let sharingFactory = AccountShareFactory()

        let presenter = ReceiveAndRequestAssetPresenter(
            wallet: wallet,
            chainAsset: chainAsset,
            qrService: qrService,
            sharingFactory: sharingFactory,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = ReceiveAndRequestAssetViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
