import UIKit
import SoraUI
import SoraFoundation
import SSFModels
import SSFQRService

final class ReceiveAndRequestAssetAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> ReceiveAndRequestAssetModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let interactor = ReceiveAndRequestAssetInteractor(
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            chainAsset: chainAsset
        )
        let router = ReceiveAndRequestAssetRouter()

        let qrService = QRServiceDefault()
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
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
