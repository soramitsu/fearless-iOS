import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore

struct CrowdloanListViewFactory {
    static func createView() -> CrowdloanListViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = CrowdloanListWireframe()

        let localizationManager = LocalizationManager.shared

        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: SettingsManager.shared)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AmountFormatterFactory(),
            asset: asset,
            chain: addressType.chain
        )

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CrowdloanListViewController(
            presenter: presenter,
            tokenSymbol: LocalizableResource { _ in asset.symbol },
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> CrowdloanListInteractor? {
        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared
        let chain = settings.selectedConnection.type.chain
        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let providerFactory = SingleValueProviderFactory.shared

        return CrowdloanListInteractor(
            runtimeService: runtimeService,
            requestOperationFactory: storageRequestFactory,
            connection: connection,
            singleValueProviderFactory: providerFactory,
            chain: chain,
            operationManager: operationManager,
            logger: Logger.shared
        )
    }
}
