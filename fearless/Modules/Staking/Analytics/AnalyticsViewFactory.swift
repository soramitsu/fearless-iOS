import Foundation
import SoraKeystore

struct AnalyticsViewFactory {
    static func createView() -> AnalyticsViewProtocol? {
        let settings = SettingsManager.shared
        let operationManager = OperationManagerFacade.sharedManager

        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)
        let chain = settings.selectedConnection.type.chain
        guard
            let accountAddress = settings.selectedAccount?.address,
            let assetId = WalletAssetId(rawValue: asset.identifier),
            let subscanUrl = assetId.subscanUrl
        else {
            return nil
        }

        let analyticsService = AnalyticsService(
            baseUrl: subscanUrl,
            address: accountAddress,
            subscanOperationFactory: SubscanOperationFactory(),
            operationManager: operationManager
        )

        let interactor = AnalyticsInteractor(analyticsService: analyticsService)
        let wireframe = AnalyticsWireframe()

        let presenter = AnalyticsPresenter(interactor: interactor, wireframe: wireframe, chain: chain)

        let view = AnalyticsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
