import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore
import FearlessUtils

struct YourValidatorListViewFactory {
    static func createView() -> YourValidatorListViewProtocol? {
        guard let interactor = createInteractor(settings: SettingsManager.shared) else {
            return nil
        }

        let wireframe = YourValidatorListWireframe()

        let settings = SettingsManager.shared
        let chain = settings.selectedConnection.type.chain
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = YourValidatorListViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory
        )

        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = YourValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol
    ) -> YourValidatorListInteractor? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let chain = settings.selectedConnection.type.chain

        let validatorOperationFactory = ValidatorOperationFactory(
            chain: chain,
            eraValidatorService: EraValidatorFacade.sharedService,
            rewardService: RewardCalculatorFacade.sharedService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: RuntimeRegistryFacade.sharedService,
            engine: engine,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        return YourValidatorListInteractor(
            chain: chain,
            providerFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            settings: settings,
            accountRepository: AnyDataProviderRepository(repository),
            runtimeService: RuntimeRegistryFacade.sharedService,
            eraValidatorService: EraValidatorFacade.sharedService,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
