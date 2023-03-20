import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils
import RobinHood

struct ControllerAccountViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> ControllerAccountViewProtocol? {
        guard
            let account = selectedAccount.fetch(for: chain.accountRequest()),
            let interactor = createInteractor(
                chain: chain,
                asset: asset,
                selectedAccount: selectedAccount
            )
        else {
            return nil
        }

        let wireframe = ControllerAccountWireframe()

        let viewModelFactory = ControllerAccountViewModelFactory(
            currentAccountItem: account,
            iconGenerator: UniversalIconGenerator(chain: chain)
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            applicationConfig: ApplicationConfig.shared,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = ControllerAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> ControllerAccountInteractor? {
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

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let feeProxy = ExtrinsicFeeProxy()

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let callFactory = SubstrateCallFactory(runtimeSpecVersion: runtimeService.runtimeSpecVersion)

        return ControllerAccountInteractor(
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedAccount
            ),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            runtimeService: runtimeService,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: operationManager,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            storageRequestFactory: storageRequestFactory,
            engine: connection,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            callFactory: callFactory
        )
    }
}
