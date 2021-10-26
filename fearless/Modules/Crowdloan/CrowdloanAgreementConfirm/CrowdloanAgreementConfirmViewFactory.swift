import Foundation
import SoraKeystore

struct CrowdloanAgreementConfirmViewFactory {
    static func createView(paraId: ParaId) -> CrowdloanAgreementConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        guard let interactor = createInteractor(for: paraId, assetId: assetId) else {
            return nil
        }
        let wireframe = CrowdloanAgreementConfirmWireframe()

        let presenter = CrowdloanAgreementConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanAgreementConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for paraId: ParaId,
        assetId _: WalletAssetId
    ) -> CrowdloanAgreementConfirmInteractor? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = RuntimeRegistryFacade.sharedService

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: engine,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        return CrowdloanAgreementConfirmInteractor(
            paraId: paraId,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService
        )
    }
}
