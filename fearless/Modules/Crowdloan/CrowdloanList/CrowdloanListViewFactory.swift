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
        let settings = SettingsManager.shared

        guard
            let connection = WebSocketService.shared.connection,
            let selectedAddress = settings.selectedAccount?.address else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain
        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let providerFactory = SingleValueProviderFactory.shared

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )

        return CrowdloanListInteractor(
            selectedAddress: selectedAddress,
            runtimeService: runtimeService,
            crowdloanOperationFactory: crowdloanOperationFactory,
            connection: connection,
            singleValueProviderFactory: providerFactory,
            chain: chain,
            operationManager: operationManager,
            logger: Logger.shared
        )
    }
}
