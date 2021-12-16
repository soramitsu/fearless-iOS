import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct ValidatorSearchViewFactory {
    private static func createInteractor(
        asset: AssetModel,
        chain: ChainModel,
        settings _: SettingsManagerProtocol
    ) -> ValidatorSearchInteractor? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            asset: asset,
            chain: chain,
            eraValidatorService: EraValidatorFacade.sharedService,
            rewardService: RewardCalculatorFacade.sharedService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: RuntimeRegistryFacade.sharedService,
            engine: engine,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        return ValidatorSearchInteractor(
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}

extension ValidatorSearchViewFactory: ValidatorSearchViewFactoryProtocol {
    static func createView(
        asset: AssetModel,
        chain: ChainModel,
        with validatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    ) -> ValidatorSearchViewProtocol? {
        guard let interactor = createInteractor(asset: asset, chain: chain, settings: SettingsManager.shared) else {
            return nil
        }

        let wireframe = ValidatorSearchWireframe()

        let viewModelFactory = ValidatorSearchViewModelFactory()

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            fullValidatorList: validatorList,
            selectedValidatorList: selectedValidatorList,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.delegate = delegate
        interactor.presenter = presenter

        let view = ValidatorSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
