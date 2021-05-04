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

        guard let interactor = createInteractor(asset: asset) else { return nil }

        let wireframe = StakingBondMoreWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
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

        guard
            let assetId = WalletAssetId(rawValue: asset.identifier),
            let connection = WebSocketService.shared.connection else {
            return nil
        }

        let providerFactory = SingleValueProviderFactory.shared

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = StakingBondMoreInteractor(
            settings: settings,
            singleValueProviderFactory: providerFactory,
            substrateProviderFactory: substrateProviderFactory,
            accountRepository: AnyDataProviderRepository(repository),
            extrinsicServiceFactoryProtocol: extrinsicServiceFactory,
            feeProxy: feeProxy,
            runtimeService: runtimeService,
            operationManager: operationManager,
            chain: settings.selectedConnection.type.chain,
            assetId: assetId
        )

        return interactor
    }
}
