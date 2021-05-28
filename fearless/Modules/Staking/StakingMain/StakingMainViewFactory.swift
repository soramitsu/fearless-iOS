import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore
import RobinHood

final class StakingMainViewFactory: StakingMainViewFactoryProtocol {
    static func createView() -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared
        let logger = Logger.shared

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        // MARK: - View

        let view = StakingMainViewController(nib: R.nib.stakingMainViewController)
        view.localizationManager = LocalizationManager.shared
        view.iconGenerator = PolkadotIconGenerator()
        view.uiFactory = UIFactory()
        view.amountFormatterFactory = AmountFormatterFactory()

        // MARK: - Interactor

        let interactor = createInteractor(
            settings: settings,
            primitiveFactory: primitiveFactory
        )

        // MARK: - Presenter

        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let stateViewModelFactory = StakingStateViewModelFactory(
            primitiveFactory: primitiveFactory,
            logger: logger
        )
        let networkInfoViewModelFactory = NetworkInfoViewModelFactory(primitiveFactory: primitiveFactory)
        let presenter = StakingMainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            viewModelFacade: viewModelFacade,
            logger: logger
        )

        // MARK: - Router

        let wireframe = StakingMainWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol,
        primitiveFactory: WalletPrimitiveFactoryProtocol
    ) -> StakingMainInteractor {
        let operationManager = OperationManagerFacade.sharedManager

        let substrateProviderFactory =
            SubstrateDataProviderFactory(
                facade: SubstrateDataStorageFacade.shared,
                operationManager: operationManager
            )

        let operationFactory = NetworkStakingInfoOperationFactory(
            eraValidatorService: EraValidatorFacade.sharedService,
            runtimeService: RuntimeRegistryFacade.sharedService
        )

        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let analyticsService: AnalyticsService? = {
            let networkType = settings.selectedConnection.type
            let primitiveFactory = WalletPrimitiveFactory(settings: settings)
            let asset = primitiveFactory.createAssetForAddressType(networkType)
            guard
                let accountAddress = settings.selectedAccount?.address,
                let assetId = WalletAssetId(rawValue: asset.identifier),
                let subscanUrl = assetId.subscanUrl
            else {
                return nil
            }
            return AnalyticsService(
                baseUrl: subscanUrl,
                address: accountAddress,
                subscanOperationFactory: SubscanOperationFactory(),
                operationManager: operationManager
            )
        }()

        return StakingMainInteractor(
            providerFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            settings: settings,
            eventCenter: EventCenter.shared,
            primitiveFactory: primitiveFactory,
            eraValidatorService: EraValidatorFacade.sharedService,
            calculatorService: RewardCalculatorFacade.sharedService,
            runtimeService: RuntimeRegistryFacade.sharedService,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: operationManager,
            eraInfoOperationFactory: operationFactory,
            applicationHandler: ApplicationHandler(),
            analyticsService: analyticsService,
            logger: Logger.shared
        )
    }
}
