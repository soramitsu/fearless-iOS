import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct ValidatorSearchViewFactory {
    private static func createContainer(flow: ValidatorSearchFlow, chainAsset: ChainAsset) -> ValidatorSearchDependencyContainer? {
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
        case let .relaychain(validatorList, selectedValidatorList, delegate):
            let viewModelState = ValidatorSearchRelaychainViewModelState(
                fullValidatorList: validatorList,
                selectedValidatorList: selectedValidatorList,
                delegate: delegate
            )
            let strategy = ValidatorSearchRelaychainStrategy(
                validatorOperationFactory: validatorOperationFactory,
                operationManager: OperationManagerFacade.sharedManager,
                output: viewModelState
            )
            let viewModelFactory = ValidatorSearchRelaychainViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain))
            return ValidatorSearchDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(validatorList, selectedValidatorList, delegate):
            let viewModelState = ValidatorSearchParachainViewModelState(
                fullValidatorList: validatorList,
                selectedValidatorList: selectedValidatorList,
                delegate: delegate
            )
            let strategy = ValidatorSearchParachainStrategy(
                validatorOperationFactory: validatorOperationFactory,
                operationManager: OperationManagerFacade.sharedManager,
                output: viewModelState
            )
            let viewModelFactory = ValidatorSearchParachainViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain))
            return ValidatorSearchDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}

extension ValidatorSearchViewFactory: ValidatorSearchViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        flow: ValidatorSearchFlow,
        wallet: MetaAccountModel
    ) -> ValidatorSearchViewProtocol? {
        guard let container = createContainer(flow: flow, chainAsset: chainAsset) else {
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
            chainAsset: chainAsset,
            wallet: wallet
        )

        interactor.presenter = presenter

        let view = ValidatorSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
