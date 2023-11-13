import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils

struct StakingRewardDestConfirmViewFactory {
    static func createView(
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel,
        for rewardDestination: RewardDestination<ChainAccountResponse>
    ) -> StakingRewardDestConfirmViewProtocol? {
        guard let interactor = createInteractor(
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        ) else {
            return nil
        }

        let wireframe = StakingRewardDestConfirmWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,

            selectedMetaAccount: selectedAccount
        )

        let presenter = StakingRewardDestConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            rewardDestination: rewardDestination,
            confirmModelFactory: StakingRewardDestConfirmVMFactory(iconGenerator: UniversalIconGenerator()),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            asset: asset,
            logger: Logger.shared
        )

        let view = StakingRewardDestConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) -> StakingRewardDestConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let keystore = Keychain()
        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: selectedAccount.metaId,
            accountResponse: accountResponse
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        return StakingRewardDestConfirmInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedAccount
            ),
            extrinsicService: extrinsicService,
            substrateProviderFactory: substrateProviderFactory,
            runtimeService: runtimeService,
            operationManager: operationManager,
            feeProxy: feeProxy,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            signingWrapper: signingWrapper,
            connection: connection,
            keystore: keystore,
            accountRepository: AnyDataProviderRepository(accountRepository),
            callFactory: callFactory
        )
    }
}
