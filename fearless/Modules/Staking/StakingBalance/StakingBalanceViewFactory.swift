import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingBalanceViewFactory {
    static func createView() -> StakingBalanceViewProtocol? {
        let settings = SettingsManager.shared
        let networkType = settings.selectedConnection.type
        let chain = networkType.chain

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)
        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        guard let interactor = createInteractor(
            settings: settings,
            assetId: assetId,
            chain: chain
        ) else { return nil }

        let wireframe = StakingBalanceWireframe()
        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )
        let viewModelFactory = StakingBalanceViewModelFactory(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )
        interactor.presenter = presenter

        let viewController = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController

        return viewController
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol,
        assetId: WalletAssetId,
        chain: Chain
    ) -> StakingBalanceInteractor? {
        guard
            let selectedAccount = settings.selectedAccount,
            let localStorageIdFactory = try? ChainStorageIdFactory(chain: chain)
        else { return nil }

        let localStorageRequestFactory = LocalStorageRequestFactory(
            remoteKeyFactory: StorageKeyFactory(),
            localKeyFactory: localStorageIdFactory
        )

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let chainStorage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()

        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let interactor = StakingBalanceInteractor(
            chain: chain,
            accountAddress: selectedAccount.address,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            chainStorage: AnyDataProviderRepository(chainStorage),
            localStorageRequestFactory: localStorageRequestFactory,
            priceProvider: priceProvider,
            providerFactory: SingleValueProviderFactory.shared,
            operationManager: OperationManagerFacade.sharedManager
        )
        return interactor
    }
}
