import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct ValidatorSearchViewFactory {
    private static func createContainer(flow: ValidatorSearchFlow, delegate _: ValidatorSearchDelegate?, chainAsset: ChainAsset) -> ValidatorSearchDependencyContainer? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let validatorOperationFactory = RelaychainValidatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            eraValidatorService: EraValidatorFacade.sharedService,
            rewardService: RewardCalculatorFacade.sharedService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: RuntimeRegistryFacade.sharedService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        switch flow {
        case let .relaychain(validatorList, selectedValidatorList):
            let viewModelState = ValidatorSearchRelaychainViewModelState(fullValidatorList: validatorList, selectedValidatorList: selectedValidatorList)
            let strategy = ValidatorSearchRelaychainStrategy(validatorOperationFactory: validatorOperationFactory, operationManager: OperationManagerFacade.sharedManager, output: viewModelState)
            let viewModelFactory = ValidatorSearchRelaychainViewModelFactory()
            return ValidatorSearchDependencyContainer(viewModelState: viewModelState, strategy: strategy, viewModelFactory: viewModelFactory)
        case .parachain:
            return nil
        }
    }
}

extension ValidatorSearchViewFactory: ValidatorSearchViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        flow: ValidatorSearchFlow,
        delegate: ValidatorSearchDelegate?
    ) -> ValidatorSearchViewProtocol? {
        guard let container = createContainer(flow: flow, delegate: delegate, chainAsset: chainAsset) else {
            return nil
        }

        let interactor = ValidatorSearchInteractor(strategy: container.strategy)
        let wireframe = ValidatorSearchWireframe()

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared,
            chainAsset: chainAsset
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
