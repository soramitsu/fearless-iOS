import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils

// swiftlint:disable function_body_length
struct ValidatorSearchViewFactory {
    private static func createContainer(
        flow: ValidatorSearchFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> ValidatorSearchDependencyContainer? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let serviceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard
            let eraValidatorService = try? serviceFactory.createEraValidatorService(
                for: chainAsset.chain
            ) else {
            return nil
        }

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        guard let rewardService = try? serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: Int16(chainAsset.asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory,
            wallet: wallet
        ) else {
            return nil
        }

        eraValidatorService.setup()
        rewardService.setup()

        let validatorOperationFactory = RelaychainValidatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardService,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            chainRegistry: chainRegistry
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet
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
            let viewModelFactory = ValidatorSearchRelaychainViewModelFactory(
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain),
                balanceViewModelFactory: balanceViewModelFactory
            )
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
            let viewModelFactory = ValidatorSearchParachainViewModelFactory(
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain),
                balanceViewModelFactory: balanceViewModelFactory,
                chainAsset: chainAsset
            )
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
        guard let container = createContainer(flow: flow, chainAsset: chainAsset, wallet: wallet) else {
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
