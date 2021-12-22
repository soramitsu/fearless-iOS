import CommonWallet
import SoraFoundation

struct ReceiveAssetViewFactory {
    static func createView(
        account: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) -> ReceiveAssetViewProtocol? {
        let wireframe = ReceiveAssetWireframe()

        let qrEncoder = CommonWallet.WalletQREncoder()
        let qrService = WalletQRService(
            operationFactory: WalletQROperationFactory(),
            encoder: qrEncoder
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
        presenter.view = view

        return view
    }
}
