import Foundation
import SoraKeystore
import SoraFoundation
import FearlessUtils
import IrohaCrypto

final class StakingRewardPayoutsViewFactory: StakingRewardPayoutsViewFactoryProtocol {
    static func createViewForNominator(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        let addressFactory = SS58AddressFactory()

        guard let rewardsUrl = chain.externalApi?.history?.url else {
            return nil
        }

        let validatorsResolutionFactory = PayoutValidatorsForNominatorFactory(
            url: rewardsUrl,
            addressFactory: addressFactory
        )

        let payoutInfoFactory = NominatorPayoutInfoFactory(
            addressPrefix: chain.addressPrefix,
            precision: Int16(asset.precision),
            addressFactory: addressFactory
        )

        return createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            stashAddress: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    static func createViewForValidator(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        let validatorsResolutionFactory = PayoutValidatorsForValidatorFactory()

        let payoutInfoFactory = ValidatorPayoutInfoFactory(
            chain: chain,
            asset: asset,
            addressFactory: SS58AddressFactory()
        )

        return createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            stashAddress: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    private static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        stashAddress: AccountAddress,
        validatorsResolutionFactory: PayoutValidatorsFactoryProtocol,
        payoutInfoFactory: PayoutInfoFactoryProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManagerFacade.sharedManager

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        let payoutService = PayoutRewardsService(
            chain: chain,
            selectedAccountAddress: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            runtimeCodingService: runtimeProvider,
            storageRequestFactory: storageRequestFactory,
            engine: connection,
            operationManager: operationManager,
            identityOperationFactory: identityOperationFactory,
            payoutInfoFactory: payoutInfoFactory,
            logger: Logger.shared
        )

        return createView(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            payoutService: payoutService
        )
    }

    private static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        payoutService: PayoutRewardsServiceProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let operationManager = OperationManagerFacade.sharedManager

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: selectedAccount
        )

        let payoutsViewModelFactory = StakingPayoutViewModelFactory(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory,
            timeFormatter: TotalTimeFormatter()
        )
        let presenter = StakingRewardPayoutsPresenter(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            viewModelFactory: payoutsViewModelFactory
        )
        let view = StakingRewardPayoutsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            countdownTimer: CountdownTimer()
        )

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let interactor = StakingRewardPayoutsInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            payoutService: payoutService,
            asset: asset,
            chain: chain,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            operationManager: operationManager,
            runtimeService: runtimeService,
            connection: connection
        )
        let wireframe = StakingRewardPayoutsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
