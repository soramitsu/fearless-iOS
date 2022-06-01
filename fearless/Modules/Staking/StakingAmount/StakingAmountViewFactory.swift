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

        guard let presenter = createPresenter(
            view: view,
            wireframe: wireframe,
            amount: amount,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else {
            return nil
        }

        guard let interactor = createInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
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
        selectedAccount: MetaAccountModel
    ) -> StakingAmountPresenter? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: selectedAccount
        )

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: selectedAccount
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
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        dataValidatingFactory.view = view

        return presenter
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingAmountInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chain.chainId
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
        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
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

        let existentialDepositService = ExistentialDepositService(
            chainAsset: chainAsset,
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
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
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            accountRepository: AnyDataProviderRepository(accountRepository),
            eraInfoOperationFactory: NetworkStakingInfoOperationFactory(),
            eraValidatorService: eraValidatorService,
            existentialDepositService: existentialDepositService
        )
    }
}
