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
        chainAsset: ChainAsset
    ) async throws -> SendDependencies {
        guard let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        if let dependencies = cachedDependencies[chainAsset.uniqueKey(accountId: accountResponse.accountId)] {
            return dependencies
        }

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

        let transferService = try await createTransferService(for: chainAsset)

        let accountInfoFetching = createAccountInfoFetching(for: chainAsset)
        let dependencies = SendDependencies(
            wallet: wallet,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            existentialDepositService: existentialDepositService,
            equilibruimTotalBalanceService: equilibruimTotalBalanceService,
            transferService: transferService,
            accountInfoFetching: accountInfoFetching
        )

        cachedDependencies[chainAsset.uniqueKey(accountId: accountResponse.accountId)] = dependencies

        return dependencies
    }

    private func createAccountInfoFetching(for chainAsset: ChainAsset) -> AccountInfoFetchingProtocol {
        if chainAsset.chain.isEthereum {
            let chainRegistry = ChainRegistryFacade.sharedRegistry
            return EthereumAccountInfoFetching(
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                chainRegistry: chainRegistry
            )
        } else {
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
    }

    private func createTransferService(for chainAsset: ChainAsset) async throws -> TransferServiceProtocol {
        guard let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }
        let keystore = Keychain()

        switch chainAsset.chain.chainBaseType {
        case .substrate:
            let chainSyncService = SSFChainRegistry.ChainSyncService(
                chainsUrl: ApplicationConfig.shared.chainListURL!,
                operationQueue: OperationQueue(),
                dataFetchFactory: SSFNetwork.NetworkOperationFactory()
            )

            let chainsTypesSyncService = SSFChainRegistry.ChainsTypesSyncService(
                url: ApplicationConfig.shared.chainsTypesURL,
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

            let accId = !accountResponse.isChainAccount ? nil : accountResponse.accountId
            let tag: String = KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accId)

            let runtimeService = try await chainRegistry.getRuntimeProvider(
                chainId: chainAsset.chain.chainId,
                usedRuntimePaths: [:],
                runtimeItem: nil
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
            let secretKey = try keystore.fetchKey(for: tag)
            let signer = TransactionSigner(publicKeyData: accountResponse.publicKey, secretKeyData: secretKey, cryptoType: SFCryptoType(accountResponse.cryptoType.utilsType))
            let callFactory = SubstrateCallFactoryAssembly.createCallFactory(forSSF: runtimeService.runtimeSpecVersion)
            return SubstrateTransferService(extrinsicService: extrinsicService, callFactory: callFactory, signer: signer)
        case .ethereum:
            let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
            let tag: String = KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

            let secretKey = try keystore.fetchKey(for: tag)

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
}
