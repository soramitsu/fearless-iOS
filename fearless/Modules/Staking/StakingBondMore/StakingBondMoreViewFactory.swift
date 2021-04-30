import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils
import CommonWallet

struct StakingBondMoreViewFactory {
    static func createView() -> StakingBondMoreViewProtocol? {
        let settings = SettingsManager.shared
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        let wireframe = StakingBondMoreWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        guard let interactor = createInteractor(asset: asset) else { return nil }
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            asset: asset
        )
        let viewController = StakingBondMoreViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController
        interactor.presenter = presenter

        return viewController
    }

    private static func createInteractor(asset: WalletAsset) -> StakingBondMoreInteractor? {
        let settings = SettingsManager.shared

        let operationManager = OperationManagerFacade.sharedManager
        let runtimeService = RuntimeRegistryFacade.sharedService

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier),
              let connection = WebSocketService.shared.connection
        else {
            return nil
        }

        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)
        guard let balanceProvider = try? providerFactory
            .getAccountProvider(
                for: selectedAccount.address,
                runtimeService: runtimeService
            )
        else {
            return nil
        }

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let stashItemProvider = substrateProviderFactory.createStashItemProvider(for: selectedAccount.address)
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = StakingBondMoreInteractor(
            priceProvider: priceProvider,
            balanceProvider: AnyDataProvider(balanceProvider),
            stashItemProvider: stashItemProvider,
            accountRepository: AnyDataProviderRepository(repository),
            extrinsicServiceFactoryProtocol: extrinsicServiceFactory,
            runtimeService: runtimeService,
            operationManager: operationManager
        )
        return interactor
    }
}
