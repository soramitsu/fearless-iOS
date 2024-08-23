import Foundation
import SSFTransferService
import SoraKeystore
import SSFStorageQueryKit
import RobinHood
import SSFUtils
import SSFModels
import SSFNetwork

final class ServiceAssembly {
    static let shared = ServiceAssembly()
    private init() {}

    lazy var chainRegistry = ChainRegistryFacade.sharedRegistry
    lazy var logger = Logger.shared
    lazy var operationManager = OperationManagerFacade.sharedManager
    lazy var substrateRepositoryFacade = SubstrateDataStorageFacade.shared
    lazy var keystore: KeystoreProtocol = Keychain()
    lazy var priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
    lazy var eventCenter = EventCenter.shared
    lazy var userDefaults = SettingsManager.shared

    private var _accountInfoRemoteServiceDefault: AccountInfoRemoteService?
    func accountInfoRemoteServiceDefault() -> AccountInfoRemoteService {
        if let _accountInfoRemoteServiceDefault {
            return _accountInfoRemoteServiceDefault
        }

        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching(),
            tonRemoteBalanceFetching: tonRemoteBalanceFetching(),
            substrateRemoteBalanceFetching: substrateRemoteBalanceFetching()
        )
        _accountInfoRemoteServiceDefault = service
        return service
    }

    private var _ethereumRemoteBalanceFetching: AccountInfoRemoteService?
    func ethereumRemoteBalanceFetching() -> AccountInfoRemoteService {
        if let _ethereumRemoteBalanceFetching {
            return _ethereumRemoteBalanceFetching
        }
        let ethereumBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
            logger: logger,
            repository: accountInfoStorageWrapper(),
            operationManager: operationManager
        )
        let service = EthereumRemoteBalanceFetching(
            chainRegistry: chainRegistry,
            repositoryWrapper: ethereumBalanceRepositoryWrapper
        )
        _ethereumRemoteBalanceFetching = service
        return service
    }

    private var _tonRemoteBalanceFetching: AccountInfoRemoteService?
    func tonRemoteBalanceFetching() -> AccountInfoRemoteService {
        if let _tonRemoteBalanceFetching {
            return _tonRemoteBalanceFetching
        }
        let tonBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
            logger: logger,
            repository: accountInfoStorageWrapper(),
            operationManager: operationManager
        )

        let service = TonRemoteBalanceFetchingImpl(
            chainRegistry: chainRegistry,
            repositoryWrapper: tonBalanceRepositoryWrapper,
            jettonInjector: tonJettonInjector()
        )
        _tonRemoteBalanceFetching = service
        return service
    }

    private var _substrateRemoteBalanceFetching: AccountInfoRemoteService?
    func substrateRemoteBalanceFetching() -> AccountInfoRemoteService {
        if let _substrateRemoteBalanceFetching {
            return _substrateRemoteBalanceFetching
        }
        let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: chainRegistry
        )
        let service = SubstrateRemoteBalanceFetchingImpl(
            storagePerformer: storagePerformer
        )
        _substrateRemoteBalanceFetching = service
        return service
    }

    private var _accountInfoStorageWrapper: AnyDataProviderRepository<AccountInfoStorageWrapper>?
    func accountInfoStorageWrapper() -> AnyDataProviderRepository<AccountInfoStorageWrapper> {
        if let _accountInfoStorageWrapper {
            return _accountInfoStorageWrapper
        }
        let service = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createAccountInfoStorageItemRepository()

        _accountInfoStorageWrapper = service
        return service
    }

    private var _existentialDepositService: ExistentialDepositServiceProtocol?
    func existentialDepositService() -> ExistentialDepositServiceProtocol {
        if let _existentialDepositService {
            return _existentialDepositService
        }
        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry
        )
        _existentialDepositService = existentialDepositService
        return existentialDepositService
    }

    func transferService(for wallet: MetaAccountModel) -> TransferService {
        TransferServiceDefault(
            wallet: wallet,
            keystore: keystore,
            chainRegistry: chainRegistry
        )
    }

    private var _storageOperationFactory: StorageRequestFactoryProtocol?
    func storageOperationFactory() -> StorageRequestFactoryProtocol {
        if let _storageOperationFactory {
            return _storageOperationFactory
        }
        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        _storageOperationFactory = storageOperationFactory
        return storageOperationFactory
    }

    private var _polkaswapService: PolkaswapService?
    func polkaswapService() -> PolkaswapService {
        if let _polkaswapService {
            return _polkaswapService
        }

        let settingsRepository: CoreDataRepository<PolkaswapRemoteSettings, CDPolkaswapRemoteSettings> =
            substrateRepositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(PolkaswapSettingMapper())
            )

        let operationFactory = PolkaswapOperationFactory(
            storageRequestFactory: storageOperationFactory(),
            chainRegistry: chainRegistry,
            chainId: Chain.soraMain.genesisHash
        )
        let polkaswapService = PolkaswapServiceImpl(
            polkaswapOperationFactory: operationFactory,
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            operationManager: operationManager
        )
        _polkaswapService = polkaswapService
        return polkaswapService
    }

    func chainModelRepository(
        for filter: NSPredicate? = NSPredicate.enabledCHain(),
        sortDescriptors: [NSSortDescriptor] = []
    ) -> AnyDataProviderRepository<ChainModel> {
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: filter,
            sortDescriptors: sortDescriptors
        )
        return AnyDataProviderRepository(chainRepository)
    }

    func asyncChainModelRepository(
        for filter: NSPredicate? = NSPredicate.enabledCHain(),
        sortDescriptors: [NSSortDescriptor] = []
    ) -> AsyncAnyRepository<ChainModel> {
        let chainRepository = ChainRepositoryFactory().createAsyncRepository(
            for: filter,
            sortDescriptors: sortDescriptors
        )
        return AsyncAnyRepository(chainRepository)
    }

    func addressChainDefiner(wallet: MetaAccountModel) -> AddressChainDefiner {
        AddressChainDefiner(
            operationManager: operationManager,
            chainModelRepository: chainModelRepository(),
            wallet: wallet
        )
    }

    func chainAssetFetching(qualityOfService: QualityOfService) -> ChainAssetFetchingProtocol {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = qualityOfService
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: chainModelRepository(),
            operationQueue: operationQueue
        )
        return chainAssetFetching
    }

    private var _scamInfoAsyncRepository: AsyncAnyRepository<ScamInfo>?
    func scamInfoAsyncRepository() -> AsyncAnyRepository<ScamInfo> {
        if let _scamInfoAsyncRepository {
            return _scamInfoAsyncRepository
        }
        let mapper: CodableCoreDataMapper<ScamInfo, CDScamInfo> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDScamInfo.address))
        let repository: AsyncCoreDataRepositoryDefault<ScamInfo, CDScamInfo> =
            substrateRepositoryFacade.createAsyncRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )
        let anyRepository = AsyncAnyRepository(repository)
        _scamInfoAsyncRepository = anyRepository
        return anyRepository
    }

    private var _tonJettonInjector: TonJettonInjector?
    func tonJettonInjector() -> TonJettonInjector {
        if let _tonJettonInjector {
            return _tonJettonInjector
        }

        let repo = asyncChainModelRepository()
        let injector = TonJettonInjectorImpl(
            chainModelRepository: repo,
            eventCenter: eventCenter,
            logger: logger
        )
        _tonJettonInjector = injector
        return injector
    }

    private var _tonConnectService: TonConnectService?
    func tonConnectService() -> TonConnectService {
        if let _tonConnectService {
            return _tonConnectService
        }

        let networkWorker = SSFNetwork.NetworkWorkerImpl()
        let eventCenter = TonConnectEventsCenter(
            chainRegistry: chainRegistry,
            lastEventStore: SettingsManager.shared,
            logger: logger
        )
        let service = TonConnectServiceImpl(
            chainRegistry: chainRegistry,
            tonService: tonSendService(),
            networkWorker: networkWorker,
            messageBuilder: TonWebBridgeMessagesBuilderImpl(),
            appRepository: tonConnectAppAsyncRepository(),
            eventCenter: eventCenter,
            logger: logger
        )
        _tonConnectService = service
        return service
    }

    private var _tonDappAsyncRepository: AsyncAnyRepository<TonDapp>?
    func tonDappAsyncRepository() -> AsyncAnyRepository<TonDapp> {
        if let _tonDappAsyncRepository {
            return _tonDappAsyncRepository
        }

        let mapper: CodableCoreDataMapper<TonDapp, CDTonDapp> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDTonDapp.identifier))
        let repo = substrateRepositoryFacade.createAsyncRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let anyRepo = AsyncAnyRepository(repo)
        _tonDappAsyncRepository = anyRepo
        return anyRepo
    }

    private var _tonConnectAppAsyncRepository: AsyncAnyRepository<TonConnectApp>?
    func tonConnectAppAsyncRepository() -> AsyncAnyRepository<TonConnectApp> {
        if let _tonConnectAppAsyncRepository {
            return _tonConnectAppAsyncRepository
        }

        let mapper: CodableCoreDataMapper<TonConnectApp, CDTonConnectedApp> = CodableCoreDataMapper()
        let repo = substrateRepositoryFacade.createAsyncRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let anyRepo = AsyncAnyRepository(repo)
        _tonConnectAppAsyncRepository = anyRepo
        return anyRepo
    }

    private var _tonSendService: TonSendService?
    func tonSendService() -> TonSendService {
        if let _tonSendService {
            return _tonSendService
        }

        let service = TonSendServiceDefault(
            chainRegistry: chainRegistry
        )
        _tonSendService = service
        return service
    }

    func tonBocFactory(
        metaId: String,
        accountResponse: ChainAccountResponse
    ) throws -> BocFactory {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = KeystoreTagV2.secretKeyTag(
            for: .ton,
            metaId: metaId,
            accountId: accountId
        )

        let secretKey = try keystore.fetchKey(for: tag)
        let factory = BocFactoryImpl(secretKey: secretKey)
        return factory
    }
}
