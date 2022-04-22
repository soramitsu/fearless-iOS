import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingRebondConfirmationViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        variant: SelectedRebondVariant
    )
        -> StakingRebondConfirmationViewProtocol? {
        guard let interactor = createInteractor(chain: chain, asset: asset, selectedAccount: selectedAccount) else {
            return nil
        }

        let wireframe = StakingRebondConfirmationWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = createPresenter(
            chain: chain,
            asset: asset,
            variant: variant,
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = StakingRebondConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    // swiftlint:disable function_parameter_count
    private static func createPresenter(
        chain: ChainModel,
        asset: AssetModel,
        variant: SelectedRebondVariant,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol
    ) -> StakingRebondConfirmationPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            settings: SettingsManager.shared
        )

        let confirmationViewModelFactory = StakingRebondConfirmationViewModelFactory(asset: asset)

        return StakingRebondConfirmationPresenter(
            variant: variant,
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            asset: asset,
            logger: Logger.shared
        )
    }

    // swiftlint:disable function_body_length
    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingRebondConfirmationInteractor? {
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

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
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

        let keystore = Keychain()
        let feeProxy = ExtrinsicFeeProxy()
        let facade = UserDataStorageFacade.shared
        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return StakingRebondConfirmationInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                selectedMetaAccount: selectedAccount
            ),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            runtimeService: runtimeService,
            operationManager: operationManager,
            keystore: keystore,
            connection: connection,
            accountRepository: AnyDataProviderRepository(accountRepository)
        )
    }
}
