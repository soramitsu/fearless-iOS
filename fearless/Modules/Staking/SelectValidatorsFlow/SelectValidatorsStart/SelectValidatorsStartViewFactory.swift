import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class SelectValidatorsStartViewFactory: SelectValidatorsStartViewFactoryProtocol {
    static func createInitiatedBondingView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        state: InitiatedBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = InitBondingSelectValidatorsStartWireframe(state: state)
        return createView(
            wallet: wallet,
            chainAsset: chainAsset,
            wireframe: wireframe,
            existingStashAddress: nil,
            selectedValidators: nil
        )
    }

    static func createChangeTargetsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = ChangeTargetsSelectValidatorsStartWireframe(state: state)
        return createView(
            wallet: wallet,
            chainAsset: chainAsset,
            wireframe: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets
        )
    }

    static func createChangeYourValidatorsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = YourValidatorList.SelectionStartWireframe(state: state)
        return createView(
            wallet: wallet,
            chainAsset: chainAsset,
            wireframe: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets
        )
    }

    private static func createView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        wireframe: SelectValidatorsStartWireframeProtocol,
        existingStashAddress: AccountAddress?,
        selectedValidators: [SelectedValidatorInfo]?
    ) -> SelectValidatorsStartViewProtocol? {
        guard let container = createContainer(
            chainAsset: chainAsset,
            existingStashAddress: existingStashAddress,
            selectedValidators: selectedValidators
        ) else {
            return nil
        }

        let interactor = SelectValidatorsStartInteractor(
            strategy: container.strategy
        )

        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            existingStashAddress: existingStashAddress,
            initialTargets: selectedValidators,
            logger: Logger.shared,
            chainAsset: chainAsset,
            wallet: wallet,
            viewModelState: container.viewModelState,
            viewModelFactory: container.viewModelFactory
        )

        let view = SelectValidatorsStartViewController(
            presenter: presenter,
            phase: selectedValidators == nil ? .setup : .update,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }

    private static func createContainer(
        chainAsset: ChainAsset,
        existingStashAddress: AccountAddress?,
        selectedValidators: [SelectedValidatorInfo]?
    ) -> SelectValidatorsStartDependencyContainer? {
        let flow: SelectValidatorsStartFlow = chainAsset.chain.isEthereumBased ? .parachain : .relaychain

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
            operationQueue: OperationManagerFacade.sharedDefaultQueue
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
                for: settings.chain.chainId
            ) else {
            return nil
        }

        guard let rewardService = try? serviceFactory.createRewardCalculatorService(
            for: settings.chain.chainId,
            assetPrecision: settings.assetDisplayInfo.assetPrecision,
            validatorService: eraValidatorService
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
        case .relaychain:
            let operationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageOperationFactory,
                runtimeService: runtimeService,
                engine: connection,
                identityOperationFactory: identityOperationFactory
            )

            let viewModelState = SelectValidatorsStartRelaychainViewModelState(
                initialTargets: selectedValidators,
                existingStashAddress: existingStashAddress
            )

            let strategy = SelectValidatorsStartRelaychainStrategy(
                operationFactory: operationFactory,
                operationManager: operationManager,
                runtimeService: runtimeService,
                output: viewModelState
            )

            let viewModelFactory = SelectValidatorsStartRelaychainViewModelFactory()
            return SelectValidatorsStartDependencyContainer(viewModelState: viewModelState, strategy: strategy, viewModelFactory: viewModelFactory)
        case .parachain:
            let operationFactory = ParachainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageOperationFactory,
                runtimeService: runtimeService,
                engine: connection,
                identityOperationFactory: identityOperationFactory
            )

            let viewModelState = SelectValidatorsStartParachainViewModelState()

            let strategy = SelectValidatorsStartParachainStrategy(
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
        }
    }
}
