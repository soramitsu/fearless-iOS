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
        let substrateProviderFactory =
            SubstrateDataProviderFactory(
                facade: SubstrateDataStorageFacade.shared,
                operationManager: OperationManagerFacade.sharedManager
            )

        let operationFactory = NetworkStakingInfoOperationFactory(
            eraValidatorService: EraValidatorFacade.sharedService,
            runtimeService: RuntimeRegistryFacade.sharedService
        )

        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return StakingMainInteractor(
            providerFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            settings: settings,
            eventCenter: EventCenter.shared,
            primitiveFactory: primitiveFactory,
            eraValidatorService: EraValidatorFacade.sharedService,
            calculatorService: RewardCalculatorFacade.sharedService,
            runtimeService: RuntimeRegistryFacade.sharedService,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: OperationManagerFacade.sharedManager,
            eraInfoOperationFactory: operationFactory,
            applicationHandler: ApplicationHandler(),
            logger: Logger.shared
        )
    }
}
