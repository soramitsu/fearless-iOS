import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation
import FearlessUtils

final class StakingAmountViewFactory: StakingAmountViewFactoryProtocol {
    static func createView(
        with amount: Decimal?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingAmountViewProtocol? {
        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)
        let wireframe = StakingAmountWireframe()

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        guard let dependencyContainer = createContainer(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            viewModelStateListener: nil,
            dataValidatingFactory: dataValidatingFactory,
            wallet: selectedAccount
        ) else {
            return nil
        }

        guard let presenter = createPresenter(
            view: view,
            wireframe: wireframe,
            amount: amount,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            viewModelState: dependencyContainer.viewModelState,
            viewModelFactory: dependencyContainer.viewModelFactory
        ) else {
            return nil
        }

        guard let interactor = createInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            strategy: dependencyContainer.strategy
        ) else {
            return nil
        }

        view.uiFactory = UIFactory()
        view.localizationManager = LocalizationManager.shared

        presenter.interactor = interactor
        interactor.presenter = presenter
        view.presenter = presenter

        return view
    }

    private static func createPresenter(
        view: StakingAmountViewProtocol,
        wireframe: StakingAmountWireframeProtocol,
        amount: Decimal?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        viewModelState: StakingAmountViewModelState?,
        viewModelFactory: StakingAmountViewModelFactoryProtocol?
    ) -> StakingAmountPresenter? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount
        )

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = StakingAmountPresenter(
            amount: amount,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount,
            rewardDestViewModelFactory: rewardDestViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared,
            viewModelState: viewModelState,
            viewModelFactory: viewModelFactory
        )

        presenter.view = view
        presenter.wireframe = wireframe
        dataValidatingFactory.view = view

        return presenter
    }

    private static func createContainer(
        chainAsset: ChainAsset,
        viewModelStateListener: StakingAmountModelStateListener?,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        wallet: MetaAccountModel
    ) -> StakingAmountDependencyContainer? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            assertionFailure("StakingAmountViewFactory.createContainer.runtimeService.missing")
            return nil
        }

        let flow: StakingAmountFlow = chainAsset.chain.isEthereumBased ? .parachain : .relaychain
        let operationManager = OperationManagerFacade.sharedManager
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            limit: StakingConstants.maxAmount
        )

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        switch flow {
        case .relaychain:
            let relaychainStakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                operationManager: operationManager,
                logger: Logger.shared
            )

            let viewModelState = StakingAmountRelaychainViewModelState(
                stateListener: viewModelStateListener,
                dataValidatingFactory: dataValidatingFactory,
                wallet: wallet,
                chainAsset: chainAsset
            )

            let strategy = StakingAmountRelaychainStrategy(
                chain: chainAsset.chain,
                runtimeService: runtimeService,
                operationManager: operationManager,
                stakingLocalSubscriptionFactory: relaychainStakingLocalSubscriptionFactory,
                extrinsicService: extrinsicService,
                output: viewModelState
            )

            let viewModelFactory = StakingAmountRelaychainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                rewardDestViewModelFactory: rewardDestViewModelFactory
            )

            return StakingAmountDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .parachain:
            let parachainStakingLocalSubscriptionFactory = ParachainStakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                operationManager: operationManager,
                logger: Logger.shared
            )

            let viewModelState = StakingAmountParachainViewModelState(
                stateListener: viewModelStateListener,
                dataValidatingFactory: dataValidatingFactory,
                wallet: wallet,
                chainAsset: chainAsset
            )

            let strategy = StakingAmountParachainStrategy(
                chainAsset: chainAsset,
                stakingLocalSubscriptionFactory: parachainStakingLocalSubscriptionFactory,
                output: viewModelState
            )

            let viewModelFactory = StakingAmountParachainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                rewardDestViewModelFactory: rewardDestViewModelFactory
            )

            return StakingAmountDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        strategy: StakingAmountStrategy?
    ) -> StakingAmountInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chain
        ) else {
            return nil
        }

        guard let rewardCalculatorService = try? serviceFactory.createRewardCalculatorService(
            for: chain.chainId,
            assetPrecision: Int16(asset.precision),
            validatorService: eraValidatorService
        ) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let logger = Logger.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return StakingAmountInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                selectedMetaAccount: selectedAccount
            ),
            extrinsicService: extrinsicService,
            rewardService: rewardCalculatorService,
            runtimeService: runtimeService,
            operationManager: operationManager,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            accountRepository: AnyDataProviderRepository(accountRepository),
            eraInfoOperationFactory: RelaychainStakingInfoOperationFactory(),
            eraValidatorService: eraValidatorService,
            strategy: strategy
        )
    }
}
