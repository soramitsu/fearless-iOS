import SSFUtils
import SoraKeystore
import RobinHood
import SSFModels
import SSFChainRegistry
import SSFNetwork
import SSFExtrinsicKit
import Web3
import SSFSigner
import SSFCrypto

struct SendDependencies {
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let runtimeService: RuntimeCodingServiceProtocol?
    let existentialDepositService: ExistentialDepositServiceProtocol
    let equilibruimTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    let transferService: TransferServiceProtocol
    let accountInfoFetching: AccountInfoFetchingProtocol
    let polkaswapService: PolkaswapService?
}

final class SendDepencyContainer {
    private let wallet: MetaAccountModel
    private let operationManager: OperationManagerProtocol
    private var currentDependecies: SendDependencies?
    private var cachedDependencies: [ChainAssetKey: SendDependencies] = [:]

    init(wallet: MetaAccountModel, operationManager: OperationManagerProtocol) {
        self.wallet = wallet
        self.operationManager = operationManager
    }

    func prepareDepencies(
        chainAsset: ChainAsset,
        runtimeItem: RuntimeMetadataItem?
    ) async throws -> SendDependencies {
        guard let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        if let dependencies = cachedDependencies[chainAsset.uniqueKey(accountId: accountResponse.accountId)] {
            return dependencies
        }
        currentDependecies?.transferService.unsubscribe()

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let runtimeService = chainRegistry.getRuntimeProvider(
            for: chainAsset.chain.chainId
        )

        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )

        let equilibruimTotalBalanceService = createEqTotalBalanceService(chainAsset: chainAsset)

        let transferService = try await createTransferService(for: chainAsset, runtimeItem: runtimeItem)
        let polkaswapService = createPolkaswapService(chainAsset: chainAsset, chainRegistry: chainRegistry)
        let accountInfoFetching = createAccountInfoFetching(for: chainAsset)
        let dependencies = SendDependencies(
            wallet: wallet,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            existentialDepositService: existentialDepositService,
            equilibruimTotalBalanceService: equilibruimTotalBalanceService,
            transferService: transferService,
            accountInfoFetching: accountInfoFetching,
            polkaswapService: polkaswapService
        )

        cachedDependencies[chainAsset.uniqueKey(accountId: accountResponse.accountId)] = dependencies
        currentDependecies = dependencies

        return dependencies
    }

    private func createAccountInfoFetching(for _: ChainAsset) -> AccountInfoFetchingProtocol {
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        let substrateAccountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return substrateAccountInfoFetching
    }

    private func createTransferService(for chainAsset: ChainAsset, runtimeItem: RuntimeMetadataItem?) async throws -> TransferServiceProtocol {
        guard
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest())
        else {
            throw ChainAccountFetchingError.accountNotExists
        }

        switch chainAsset.chain.chainBaseType {
        case .substrate:
            guard let nativeRuntimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let chainSyncService = SSFChainRegistry.ChainSyncService(
                chainsUrl: ApplicationConfig.shared.chainsSourceUrl,
                operationQueue: OperationQueue(),
                dataFetchFactory: SSFNetwork.NetworkOperationFactory()
            )

            let chainsTypesSyncService = SSFChainRegistry.ChainsTypesSyncService(
                url: ApplicationConfig.shared.chainTypesSourceUrl,
                dataOperationFactory: SSFNetwork.NetworkOperationFactory(),
                operationQueue: OperationQueue()
            )

            let runtimeSyncService = SSFChainRegistry.RuntimeSyncService(dataOperationFactory: NetworkOperationFactory())

            let chainRegistry = SSFChainRegistry.ChainRegistry(
                runtimeProviderPool: SSFChainRegistry.RuntimeProviderPool(),
                connectionPool: SSFChainRegistry.ConnectionPool(),
                chainSyncService: chainSyncService,
                chainsTypesSyncService: chainsTypesSyncService,
                runtimeSyncService: runtimeSyncService
            )
            let connection = try chainRegistry.getConnection(for: chainAsset.chain)

            let runtimeService = try await chainRegistry.getRuntimeProvider(
                chainId: chainAsset.chain.chainId,
                usedRuntimePaths: [:],
                runtimeItem: runtimeItem
            )

            let operationManager = OperationManagerFacade.sharedManager

            let extrinsicService = SSFExtrinsicKit.ExtrinsicService(
                accountId: accountResponse.accountId,
                chainFormat: chainAsset.chain.chainFormat.asSfCrypto(),
                cryptoType: SFCryptoType(accountResponse.cryptoType.utilsType),
                runtimeRegistry: runtimeService,
                engine: connection,
                operationManager: operationManager
            )
            let secretKey = try fetchSecretKey(for: chainAsset.chain, accountResponse: accountResponse)
            let signer = TransactionSigner(
                publicKeyData: accountResponse.publicKey,
                secretKeyData: secretKey,
                cryptoType: SFCryptoType(utilsType: accountResponse.cryptoType.utilsType, isEthereum: chainAsset.chain.isEthereumBased)
            )

            let callFactory = SubstrateCallFactoryDefault(runtimeService: nativeRuntimeService)
            return SubstrateTransferService(extrinsicService: extrinsicService, callFactory: callFactory, signer: signer)
        case .ethereum:
            let secretKey = try fetchSecretKey(for: chainAsset.chain, accountResponse: accountResponse)

            guard let address = accountResponse.toAddress() else {
                throw ConvenienceError(error: "Cannot fetch address from chain account")
            }

            guard let ws = ChainRegistryFacade.sharedRegistry.getEthereumConnection(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            return EthereumTransferService(
                ws: ws,
                privateKey: try EthereumPrivateKey(privateKey: secretKey.bytes),
                senderAddress: address
            )
        }
    }

    private func createEqTotalBalanceService(chainAsset: ChainAsset) -> EquilibriumTotalBalanceServiceProtocol? {
        guard chainAsset.chain.isEquilibrium else {
            return nil
        }
        if let equilibruimTotalBalanceService = currentDependecies?.equilibruimTotalBalanceService {
            return equilibruimTotalBalanceService
        }
        return EquilibriumTotalBalanceServiceFactory
            .createService(wallet: wallet, chainAsset: chainAsset)
    }

    private func fetchSecretKey(
        for chain: ChainModel,
        accountResponse: ChainAccountResponse
    ) throws -> Data {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

        let keystore = Keychain()
        let secretKey = try keystore.fetchKey(for: tag)
        return secretKey
    }

    private func createPolkaswapService(
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol
    ) -> PolkaswapService? {
        guard chainAsset.chain.isSora else {
            return nil
        }
        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let repositoryFacade = SubstrateDataStorageFacade.shared
        let settingsRepository: CoreDataRepository<PolkaswapRemoteSettings, CDPolkaswapRemoteSettings> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(PolkaswapSettingMapper())
            )
        let operationFactory = PolkaswapOperationFactory(
            storageRequestFactory: storageOperationFactory,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )
        let polkaswapService = PolkaswapServiceImpl(
            polkaswapOperationFactory: operationFactory,
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            operationManager: operationManager
        )
        return polkaswapService
    }
}
