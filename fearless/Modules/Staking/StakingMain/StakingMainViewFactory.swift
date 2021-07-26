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

        // MARK: - Router

        let wireframe = StakingMainWireframe()

        // MARK: - Presenter

        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let stateViewModelFactory = StakingStateViewModelFactory(
            primitiveFactory: primitiveFactory,
            logger: logger
        )
        let networkInfoViewModelFactory = NetworkInfoViewModelFactory(primitiveFactory: primitiveFactory)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingMainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol,
        primitiveFactory: WalletPrimitiveFactoryProtocol
    ) -> StakingMainInteractor {
        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager
        let eraValidatorService = EraValidatorFacade.sharedService

        let substrateProviderFactory =
            SubstrateDataProviderFactory(
                facade: SubstrateDataStorageFacade.shared,
                operationManager: operationManager
            )

        let operationFactory = NetworkStakingInfoOperationFactory(
            eraValidatorService: eraValidatorService,
            runtimeService: runtimeService
        )

        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            webSocketService: WebSocketService.shared
        )

        return StakingMainInteractor(
            providerFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            settings: settings,
            eventCenter: EventCenter.shared,
            primitiveFactory: primitiveFactory,
            eraValidatorService: eraValidatorService,
            calculatorService: RewardCalculatorFacade.sharedService,
            runtimeService: runtimeService,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: operationManager,
            eraInfoOperationFactory: operationFactory,
            applicationHandler: ApplicationHandler(),
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            logger: Logger.shared
        )
    }
}
