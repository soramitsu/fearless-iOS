import SoraFoundation
import SoraUI

struct ReceiveAssetViewFactory {
    static func createView(
        account: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) -> ReceiveAssetViewProtocol? {
        let wireframe = ReceiveAssetWireframe()

        let qrService = QRService(
            operationFactory: QROperationFactory(),
            encoder: QREncoder()
        )
        let sharingFactory = AccountShareFactory()
        let presenter = ReceiveAssetPresenter(
            wireframe: wireframe,
            qrService: qrService,
            sharingFactory: sharingFactory,
            account: account,
            chain: chain,
            asset: asset,
            localizationManager: LocalizationManager.shared
        )

        let view = ReceiveAssetViewController(presenter: presenter)
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory
        presenter.view = view

        return view
    }
}
