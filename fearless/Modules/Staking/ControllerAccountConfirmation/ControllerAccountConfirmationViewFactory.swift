import Foundation
import SoraFoundation
import SSFUtils
import SoraKeystore
import RobinHood
import SSFModels

struct ControllerAccountConfirmationViewFactory {
    static func createView(
        controllerAccountItem: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> ControllerAccountConfirmationViewProtocol? {
        guard let interactor = createInteractor(
            controllerAccountItem: controllerAccountItem,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else {
            return nil
        }

        let wireframe = ControllerAccountConfirmationWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            selectedMetaAccount: selectedAccount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = ControllerAccountConfirmationPresenter(
            controllerAccountItem: controllerAccountItem,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = ControllerAccountConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        controllerAccountItem: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> ControllerAccountConfirmationInteractor? {
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

        let keystore = Keychain()
        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: selectedAccount.metaId,
            accountResponse: accountResponse
        )

        let feeProxy = ExtrinsicFeeProxy()

        let facade = UserDataStorageFacade.shared

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        return ControllerAccountConfirmationInteractor(
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedAccount
            ),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            priceLocalSubscriber: priceLocalSubscriber,
            runtimeService: runtimeService,
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            feeProxy: feeProxy,
            controllerAccountItem: controllerAccountItem,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: operationManager,
            storageRequestFactory: storageRequestFactory,
            engine: connection,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            callFactory: callFactory
        )
    }
}
