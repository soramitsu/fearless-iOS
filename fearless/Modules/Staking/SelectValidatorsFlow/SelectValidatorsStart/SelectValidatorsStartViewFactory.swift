import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class SelectValidatorsStartViewFactory: SelectValidatorsStartViewFactoryProtocol {
    static func createInitiatedBondingView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        state: InitiatedBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = InitBondingSelectValidatorsStartWireframe(state: state)
        return createView(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            wireframe: wireframe,
            existingStashAddress: nil,
            selectedValidators: nil
        )
    }

    static func createChangeTargetsView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = ChangeTargetsSelectValidatorsStartWireframe(state: state)
        return createView(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            wireframe: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets
        )
    }

    static func createChangeYourValidatorsView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = YourValidatorList.SelectionStartWireframe(state: state)
        return createView(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            wireframe: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets
        )
    }

    private static func createView(
        selectedAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        wireframe: SelectValidatorsStartWireframeProtocol,
        existingStashAddress: AccountAddress?,
        selectedValidators: [SelectedValidatorInfo]?
    ) -> SelectValidatorsStartViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
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

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: stakingSettings.value.chain.chainId
        ) else {
            return nil
        }

        guard let rewardService = try? serviceFactory.createRewardCalculatorService(
            for: stakingSettings.value.chain.chainId,
            assetPrecision: stakingSettings.value.assetDisplayInfo.assetPrecision,
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

        let operationFactory = ValidatorOperationFactory(
            asset: asset,
            chain: chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardService,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: identityOperationFactory
        )

        let interactor = SelectValidatorsStartInteractor(
            runtimeService: runtimeService,
            operationFactory: operationFactory,
            operationManager: operationManager
        )

        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            existingStashAddress: existingStashAddress,
            initialTargets: selectedValidators,
            logger: Logger.shared,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
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
}
