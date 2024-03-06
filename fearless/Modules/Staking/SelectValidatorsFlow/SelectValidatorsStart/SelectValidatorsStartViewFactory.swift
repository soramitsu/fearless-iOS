import Foundation
import SSFUtils
import SoraKeystore
import SoraFoundation
import SSFModels

final class SelectValidatorsStartViewFactory: SelectValidatorsStartViewFactoryProtocol {
    static func createView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsStartFlow
    ) -> SelectValidatorsStartViewProtocol? {
        guard let container = createContainer(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet
        ) else {
            return nil
        }

        let wireframe = SelectValidatorsStartWireframe()
        let interactor = SelectValidatorsStartInteractor(
            strategy: container.strategy
        )

        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared,
            chainAsset: chainAsset,
            wallet: wallet,
            viewModelState: container.viewModelState,
            viewModelFactory: container.viewModelFactory
        )

        let view = SelectValidatorsStartViewController(
            presenter: presenter,
            phase: flow.phase,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }

    // swiftlint:disable function_body_length
    private static func createContainer(
        flow: SelectValidatorsStartFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> SelectValidatorsStartDependencyContainer? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let stakingSettings = StakingAssetSettings(
            storageFacade: substrateStorageFacade,
            settings: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            wallet: wallet
        )

        stakingSettings.setup()

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard
            let settings = stakingSettings.value,
            let eraValidatorService = try? serviceFactory.createEraValidatorService(
                for: settings.chain
            ) else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

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
            assetPrecision: settings.assetDisplayInfo.assetPrecision,
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory
        ) else {
            return nil
        }

        eraValidatorService.setup()
        rewardService.setup()

        let operationManager = OperationManagerFacade.sharedManager
        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        switch flow {
        case let .relaychainExisting(bonding):
            let operationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageOperationFactory,
                identityOperationFactory: identityOperationFactory,
                chainRegistry: chainRegistry
            )

            let viewModelState = SelectValidatorsStartRelaychainExistingViewModelState(
                bonding: bonding,
                initialTargets: bonding.selectedTargets,
                existingStashAddress: bonding.stashAddress
            )

            let strategy = SelectValidatorsStartRelaychainStrategy(
                operationFactory: operationFactory,
                operationManager: operationManager,
                runtimeService: runtimeService,
                output: viewModelState
            )

            let viewModelFactory = SelectValidatorsStartRelaychainViewModelFactory()
            return SelectValidatorsStartDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .relaychainInitiated(bonding):
            let operationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageOperationFactory,
                identityOperationFactory: identityOperationFactory,
                chainRegistry: chainRegistry
            )

            let viewModelState = SelectValidatorsStartRelaychainInitiatedViewModelState(
                bonding: bonding,
                initialTargets: nil,
                existingStashAddress: nil
            )

            let strategy = SelectValidatorsStartRelaychainStrategy(
                operationFactory: operationFactory,
                operationManager: operationManager,
                runtimeService: runtimeService,
                output: viewModelState
            )

            let viewModelFactory = SelectValidatorsStartRelaychainViewModelFactory()
            return SelectValidatorsStartDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .poolInitiated(poolId, bonding):
            let operationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageOperationFactory,
                identityOperationFactory: identityOperationFactory,
                chainRegistry: chainRegistry
            )

            let viewModelState = SelectValidatorsStartPoolInitiatedViewModelState(
                poolId: poolId,
                bonding: bonding,
                initialTargets: nil,
                existingStashAddress: nil
            )

            let strategy = SelectValidatorsStartPoolStrategy(
                operationFactory: operationFactory,
                operationManager: operationManager,
                runtimeService: runtimeService,
                output: viewModelState
            )

            let viewModelFactory = SelectValidatorsStartPoolInitiatedViewModelFactory()
            return SelectValidatorsStartDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(bonding):
            let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

            let operationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageOperationFactory,
                identityOperationFactory: identityOperationFactory,
                subqueryOperationFactory: rewardOperationFactory,
                chainRegistry: chainRegistry
            )

            let viewModelState = SelectValidatorsStartParachainViewModelState(bonding: bonding, chainAsset: chainAsset)

            let strategy = SelectValidatorsStartParachainStrategy(
                wallet: wallet,
                chainAsset: chainAsset,
                operationFactory: operationFactory,
                operationManager: operationManager,
                runtimeService: runtimeService,
                output: viewModelState
            )

            let viewModelFactory = SelectValidatorsStartParachainViewModelFactory()
            return SelectValidatorsStartDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .poolExisting(poolId, bonding):
            let operationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageOperationFactory,
                identityOperationFactory: identityOperationFactory,
                chainRegistry: chainRegistry
            )

            let viewModelState = SelectValidatorsStartPoolExistingViewModelState(
                poolId: poolId,
                bonding: bonding,
                initialTargets: bonding.selectedTargets,
                existingStashAddress: bonding.stashAddress
            )

            let strategy = SelectValidatorsStartPoolStrategy(
                operationFactory: operationFactory,
                operationManager: operationManager,
                runtimeService: runtimeService,
                output: viewModelState
            )

            let viewModelFactory = SelectValidatorsStartPoolExistingViewModelFactory()
            return SelectValidatorsStartDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
