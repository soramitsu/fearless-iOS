import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingBalanceViewFactory {
    static func createView() -> StakingBalanceViewProtocol? {
        guard let interactor = createInteractor() else { return nil }
        let wireframe = StakingBalanceWireframe()
        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe
        )
        interactor.presenter = presenter

        let viewController = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController

        return viewController
    }

    private static func createInteractor() -> StakingBalanceInteractor? {
        let settings = SettingsManager.shared
        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let networkType = settings.selectedConnection.type
        guard let localStorageIdFactory = try? ChainStorageIdFactory(chain: networkType.chain) else { return nil }
        let localStorageRequestFactory = LocalStorageRequestFactory(
            remoteKeyFactory: StorageKeyFactory(),
            localKeyFactory: localStorageIdFactory
        )

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let chainStorage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)
        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }
        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let interactor = StakingBalanceInteractor(
            accountAddress: selectedAccount.address,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            chainStorage: AnyDataProviderRepository(chainStorage),
            localStorageRequestFactory: localStorageRequestFactory,
            priceProvider: priceProvider,
            operationManager: OperationManagerFacade.sharedManager
        )
        return interactor
    }
}
