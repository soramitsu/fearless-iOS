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
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    ) -> StakingAmountViewProtocol? {
        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)
        let wireframe = StakingAmountWireframe()

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            selectedMetaAccount: selectedAccount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        guard let dependencyContainer = createContainer(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            dataValidatingFactory: dataValidatingFactory,
            wallet: selectedAccount,
            amount: amount,
            rewardChainAsset: rewardChainAsset
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

        dataValidatingFactory.view = view
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

            selectedMetaAccount: selectedAccount
        )

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,

            selectedMetaAccount: selectedAccount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: UniversalIconGenerator(chain: chain)
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

    // swiftlint:disable function_body_length
    private static func createContainer(
        chainAsset: ChainAsset,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        wallet: MetaAccountModel,
        amount: Decimal?,
        rewardChainAsset: ChainAsset?
    ) -> StakingAmountDependencyContainer? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let flow: StakingAmountFlow = chainAsset.chain.isEthereumBased ? .parachain : .relaychain
        let operationManager = OperationManagerFacade.sharedManager
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        ) else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet
        )

        let rewardChainAsset = rewardChainAsset ?? chainAsset
        let rewardBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: rewardChainAsset.asset.displayInfo,
            selectedMetaAccount: wallet
        )

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: rewardBalanceViewModelFactory,
            iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
        )

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
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
                dataValidatingFactory: dataValidatingFactory,
                wallet: wallet,
                chainAsset: chainAsset,
                amount: amount,
                callFactory: callFactory
            )

            let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

            let strategy = StakingAmountRelaychainStrategy(
                chainAsset: chainAsset,
                runtimeService: runtimeService,
                operationManager: operationManager,
                stakingLocalSubscriptionFactory: relaychainStakingLocalSubscriptionFactory,
                extrinsicService: extrinsicService,
                output: viewModelState,
                eraInfoOperationFactory: RelaychainStakingInfoOperationFactory(),
                eraValidatorService: eraValidatorService,
                existentialDepositService: existentialDepositService,
                rewardChainAsset: rewardChainAsset,
                priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
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
                dataValidatingFactory: dataValidatingFactory,
                wallet: wallet,
                chainAsset: chainAsset,
                amount: amount,
                callFactory: callFactory
            )

            let strategy = StakingAmountParachainStrategy(
                chainAsset: chainAsset,
                stakingLocalSubscriptionFactory: parachainStakingLocalSubscriptionFactory,
                output: viewModelState,
                extrinsicService: extrinsicService,
                eraInfoOperationFactory: ParachainStakingInfoOperationFactory(),
                eraValidatorService: eraValidatorService,
                runtimeService: runtimeService,
                operationManager: operationManager,
                existentialDepositService: existentialDepositService
            )

            let viewModelFactory = StakingAmountParachainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                rewardDestViewModelFactory: rewardDestViewModelFactory,
                accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)), wallet: wallet
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
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let chainAsset = ChainAsset(chain: chain, asset: asset)

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

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let rewardOperationFactory = RewardOperationFactory.factory(blockExplorer: chainAsset.chain.externalApi?.staking)
        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: asset,
            chain: chain,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: rewardOperationFactory
        )

        guard let rewardCalculatorService = try? serviceFactory.createRewardCalculatorService(
            for: ChainAsset(chain: chain, asset: asset),
            assetPrecision: Int16(asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory,
            wallet: selectedAccount
        ) else {
            return nil
        }

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId)
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let facade = UserDataStorageFacade.shared
        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return StakingAmountInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedAccount
            ),
            rewardService: rewardCalculatorService,
            runtimeService: runtimeService,
            operationManager: operationManager,
            chainAsset: chainAsset,
            wallet: selectedAccount,
            accountRepository: AnyDataProviderRepository(accountRepository),
            strategy: strategy
        )
    }
}
