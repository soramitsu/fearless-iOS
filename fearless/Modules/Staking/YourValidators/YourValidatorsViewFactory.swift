import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore
import FearlessUtils

final class YourValidatorsViewFactory: YourValidatorsViewFactoryProtocol {
    static func createView() -> YourValidatorsViewProtocol? {
        guard let interactor = createInteractor(settings: SettingsManager.shared) else {
            return nil
        }

        let wireframe = YourValidatorsWireframe()
        let presenter = YourValidatorsPresenter(interactor: interactor, wireframe: wireframe)

        let view = YourValidatorsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol
    ) -> YourValidatorsInteractor? {
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

        return YourValidatorsInteractor(
            chain: chain,
            providerFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            settings: settings,
            eventCenter: EventCenter.shared,
            accountRepository: AnyDataProviderRepository(repository),
            runtimeService: RuntimeRegistryFacade.sharedService,
            calculatorService: RewardCalculatorFacade.sharedService,
            eraValidatorService: EraValidatorFacade.sharedService,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
