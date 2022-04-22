import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class ValidatorInfoViewFactory {
    private static func createView(
        asset: AssetModel,
        chain: ChainModel,
        interactor: ValidatorInfoInteractorBase
    ) -> ValidatorInfoViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            settings: SettingsManager.shared
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        let wireframe = ValidatorInfoWireframe()

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            chain: chain,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ValidatorInfoViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

extension ValidatorInfoViewFactory: ValidatorInfoViewFactoryProtocol {
    static func createView(
        asset: AssetModel,
        chain: ChainModel,
        validatorInfo: ValidatorInfoProtocol
    ) -> ValidatorInfoViewProtocol? {
        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

        let interactor = AnyValidatorInfoInteractor(
            validatorInfo: validatorInfo,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            asset: asset
        )

        return createView(asset: asset, chain: chain, interactor: interactor)
    }

    static func createView(
        address: AccountAddress,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) -> ValidatorInfoViewProtocol? {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let validatorOperationFactory = ValidatorOperationFactory(
            asset: asset,
            chain: chain,
            eraValidatorService: EraValidatorFacade.sharedService,
            rewardService: RewardCalculatorFacade.sharedService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

        let interactor = YourValidatorInfoInteractor(
            accountAddress: address,
            selectedAccount: selectedAccount,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            asset: asset,
            chain: chain,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )

        return createView(
            asset: asset,
            chain: chain,
            interactor: interactor
        )
    }
}
