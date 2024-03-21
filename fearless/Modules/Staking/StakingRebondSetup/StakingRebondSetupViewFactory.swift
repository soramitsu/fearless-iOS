import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFModels
import SSFAccountManagmentStorage

final class StakingRebondSetupViewFactory: StakingRebondSetupViewFactoryProtocol {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingRebondSetupViewProtocol? {
        // MARK: - Interactor

        let settings = SettingsManager.shared

        guard let interactor = createInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            settings: settings
        ) else {
            return nil
        }

        // MARK: - Router

        let wireframe = StakingRebondSetupWireframe()

        // MARK: - Presenter

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,

            selectedMetaAccount: selectedAccount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        )

        // MARK: - View

        let localizationManager = LocalizationManager.shared

        let view = StakingRebondSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )
        view.localizationManager = localizationManager

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    // swiftlint:disable function_body_length
    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        settings _: SettingsManagerProtocol
    ) -> StakingRebondSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = ChainAsset(chain: chain, asset: asset)

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

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let feeProxy = ExtrinsicFeeProxy()

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        return StakingRebondSetupInteractor(
            priceLocalSubscriber: priceLocalSubscriber,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedAccount
            ),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            feeProxy: feeProxy,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            connection: connection,
            extrinsicService: extrinsicService,
            accountRepository: AnyDataProviderRepository(accountRepository),
            callFactory: callFactory
        )
    }
}
