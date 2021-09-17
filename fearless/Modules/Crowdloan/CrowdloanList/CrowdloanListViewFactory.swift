import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore
import IrohaCrypto

struct CrowdloanListViewFactory {
    static func createView() -> CrowdloanListViewProtocol? {
        let settings = SettingsManager.shared

        let crowdloanSettings = CrowdloanChainSettings(
            storageFacade: SubstrateDataStorageFacade.shared,
            settings: settings,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        guard let interactor = createInteractor(from: crowdloanSettings) else {
            return nil
        }

        let wireframe = CrowdloanListWireframe()

        let localizationManager = LocalizationManager.shared

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

    private static func createInteractor(from settings: CrowdloanChainSettings) -> CrowdloanListInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let selectedWallet = SelectedWalletSettings.shared.value,
            let selectedChain = settings.value,
            let selectedAsset = selectedChain.assets.first(where: { $0.isUtility }),
            let connection = chainRegistry.getConnection(for: selectedChain.chainId),
            let selectedAddress = try? SS58AddressFactory().address(
                fromAccountId: selectedWallet.substrateAccountId,
                type: selectedChain.addressPrefix
            ) else {
            return nil
        }

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
            chain: .polkadot,
            operationManager: operationManager,
            logger: Logger.shared
        )
    }
}
