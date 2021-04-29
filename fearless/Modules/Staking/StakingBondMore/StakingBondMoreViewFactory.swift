import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingBondMoreViewFactory {
    static func createView() -> StakingBondMoreViewProtocol? {
        let settings = SettingsManager.shared
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)
        let operationManager = OperationManagerFacade.sharedManager
        let runtimeService = RuntimeRegistryFacade.sharedService

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier),
              let connection = WebSocketService.shared.connection
        else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

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

        let interactor = StakingBondMoreInteractor(
            priceProvider: priceProvider,
            balanceProvider: AnyDataProvider(balanceProvider),
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            operationManager: operationManager
        )
        let wireframe = StakingBondMoreWireframe()
        // let viewModelFactory = StakingBondMoreViewModelFactory()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let viewController = StakingBondMoreViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController
        interactor.presenter = presenter

        return viewController
    }
}
