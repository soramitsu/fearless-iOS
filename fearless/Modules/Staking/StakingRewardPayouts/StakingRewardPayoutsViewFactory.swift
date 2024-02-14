import Foundation
import SoraKeystore
import SoraFoundation
import SSFUtils
import IrohaCrypto
import SSFModels

final class StakingRewardPayoutsViewFactory: StakingRewardPayoutsViewFactoryProtocol {
    static func createViewForNominator(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        let validatorsResolutionFactory = PayoutValidatorsFactoryAssembly.createPayoutValidatorsFactory(chainAsset: chainAsset)

        let payoutInfoFactory = NominatorPayoutInfoFactory(
            addressPrefix: chainAsset.chain.addressPrefix,
            precision: Int16(chainAsset.asset.precision),
            chainAsset: chainAsset
        )

        return createView(
            chainAsset: chainAsset,
            wallet: wallet,
            stashAddress: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    static func createViewForValidator(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        let validatorsResolutionFactory = PayoutValidatorsForValidatorFactory(chainAsset: chainAsset)

        let payoutInfoFactory = ValidatorPayoutInfoFactory(
            chainAsset: chainAsset
        )

        return createView(
            chainAsset: chainAsset,
            wallet: wallet,
            stashAddress: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    private static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        stashAddress: AccountAddress,
        validatorsResolutionFactory: PayoutValidatorsFactoryProtocol?,
        payoutInfoFactory: PayoutInfoFactoryProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManagerFacade.sharedManager

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        let payoutService = PayoutRewardsService(
            chain: chainAsset.chain,
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
            chainAsset: chainAsset,
            wallet: wallet,
            payoutService: payoutService
        )
    }

    private static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        payoutService: PayoutRewardsServiceProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let operationManager = OperationManagerFacade.sharedManager

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet
        )

        let payoutsViewModelFactory = StakingPayoutViewModelFactory(
            chain: chainAsset.chain,
            balanceViewModelFactory: balanceViewModelFactory,
            timeFormatter: TotalTimeFormatter()
        )
        let presenter = StakingRewardPayoutsPresenter(
            chainAsset: chainAsset,
            wallet: wallet,
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
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let interactor = StakingRewardPayoutsInteractor(
            priceLocalSubscriber: priceLocalSubscriber,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            payoutService: payoutService,
            chainAsset: chainAsset,
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
