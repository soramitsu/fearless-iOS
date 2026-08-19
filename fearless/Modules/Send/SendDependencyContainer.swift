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
import Foundation
import SSFRuntimeCodingService
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

struct SendDependencies {
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let runtimeService: RuntimeCodingServiceProtocol?
    let existentialDepositService: ExistentialDepositServiceProtocol
    let equilibruimTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    let transferService: TransferServiceProtocol
    let accountInfoFetching: AccountInfoFetchingProtocol
    let polkaswapService: PolkaswapService?
    let storageRequestPerformer: StorageRequestPerformer?
}

enum UniversalWalletSendRoutingError: Error, Equatable {
    case unsupported(chainId: String)
    case tonProductionSendDisabled
    case irohaProductionSendDisabled
}

/// Native TON routing remains disabled in production until funded mainnet evidence is recorded.
/// There is intentionally no environment-variable, remote-config, or runtime-toggle override.
struct TonProductionSendReleasePolicy: Equatable {
    let isEnabled: Bool

    private init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    static let production = TonProductionSendReleasePolicy(isEnabled: false)
    #if DEBUG
        static let enabledForTests = TonProductionSendReleasePolicy(isEnabled: true)
    #endif
}

final class SendDepencyContainer {
    private let wallet: MetaAccountModel
    private let operationManager: OperationManagerProtocol
    private let tonRemote: TonTransferRemoteProtocol?
    private let tonMnemonicProvider: UniversalWalletMnemonicProviding
    private let tonPendingCoordinator: TonPendingIntentCoordinator?
    private let tonSendReleasePolicy: TonProductionSendReleasePolicy
    private var currentDependecies: SendDependencies?
    private var currentDependenciesKey: ChainAssetKey?
    private var cachedDependencies: [ChainAssetKey: SendDependencies] = [:]

    convenience init(
        wallet: MetaAccountModel,
        operationManager: OperationManagerProtocol,
        tonRemote: TonTransferRemoteProtocol? = nil,
        tonMnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider()
    ) {
        self.init(
            wallet: wallet,
            operationManager: operationManager,
            tonRemote: tonRemote,
            tonMnemonicProvider: tonMnemonicProvider,
            tonPendingCoordinator: nil,
            releasePolicy: .production
        )
    }

    #if DEBUG
        convenience init(
            wallet: MetaAccountModel,
            operationManager: OperationManagerProtocol,
            tonRemote: TonTransferRemoteProtocol? = nil,
            tonMnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider(),
            tonPendingCoordinator: TonPendingIntentCoordinator = TonPendingIntentCoordinator(),
            tonSendReleasePolicy: TonProductionSendReleasePolicy
        ) {
            self.init(
                wallet: wallet,
                operationManager: operationManager,
                tonRemote: tonRemote,
                tonMnemonicProvider: tonMnemonicProvider,
                tonPendingCoordinator: tonPendingCoordinator,
                releasePolicy: tonSendReleasePolicy
            )
        }
    #endif

    private init(
        wallet: MetaAccountModel,
        operationManager: OperationManagerProtocol,
        tonRemote: TonTransferRemoteProtocol?,
        tonMnemonicProvider: UniversalWalletMnemonicProviding,
        tonPendingCoordinator: TonPendingIntentCoordinator?,
        releasePolicy: TonProductionSendReleasePolicy
    ) {
        self.wallet = wallet
        self.operationManager = operationManager
        self.tonRemote = tonRemote
        self.tonMnemonicProvider = tonMnemonicProvider
        self.tonPendingCoordinator = tonPendingCoordinator
        tonSendReleasePolicy = releasePolicy
    }

    @MainActor
    func prepareDepencies(chainAsset: ChainAsset) async throws -> SendDependencies {
        // This guard must precede account lookup, dependency cache access, and all service or
        // transport construction. Release builds have no initializer capable of enabling it.
        if chainAsset.chain.isTonCompatibilityChain, !tonSendReleasePolicy.isEnabled {
            throw UniversalWalletSendRoutingError.tonProductionSendDisabled
        }
        if isUniversalWalletIroha(chainAsset.chain) {
            throw UniversalWalletSendRoutingError.irohaProductionSendDisabled
        }

        guard let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        let dependenciesKey = chainAsset.uniqueKey(accountId: accountResponse.accountId)
        if let dependencies = cachedDependencies[dependenciesKey] {
            if currentDependenciesKey != dependenciesKey {
                currentDependecies?.transferService.unsubscribe()
                currentDependecies = dependencies
                currentDependenciesKey = dependenciesKey
            }
            return dependencies
        }
        if currentDependenciesKey != dependenciesKey {
            currentDependecies?.transferService.unsubscribe()
        }

        let chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry
        let runtimeService = chainRegistry.getRuntimeProvider(
            for: chainAsset.chain.chainId
        )

        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )

        let equilibruimTotalBalanceService = createEqTotalBalanceService(chainAsset: chainAsset)

        let transferService = try createTransferService(for: chainAsset)
        let polkaswapService = createPolkaswapService(chainAsset: chainAsset, chainRegistry: chainRegistry)
        let accountInfoFetching = createAccountInfoFetching(for: chainAsset)

        let storageRequestPerformer: StorageRequestPerformer? = runtimeService.flatMap {
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
                return nil
            }

            return StorageRequestPerformerDefault(runtimeService: $0, connection: connection)
        }
        let dependencies = SendDependencies(
            wallet: wallet,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            existentialDepositService: existentialDepositService,
            equilibruimTotalBalanceService: equilibruimTotalBalanceService,
            transferService: transferService,
            accountInfoFetching: accountInfoFetching,
            polkaswapService: polkaswapService,
            storageRequestPerformer: storageRequestPerformer
        )

        cachedDependencies[dependenciesKey] = dependencies
        currentDependecies = dependencies
        currentDependenciesKey = dependenciesKey

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

    private func createTransferService(for chainAsset: ChainAsset) throws -> TransferServiceProtocol {
        guard
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest())
        else {
            throw ChainAccountFetchingError.accountNotExists
        }

        if isUniversalWalletBitcoin(chainAsset.chain) {
            return BitcoinTransferService(wallet: wallet, chain: chainAsset.chain)
        }

        if isUniversalWalletSolana(chainAsset.chain) {
            return try SolanaTransferService(wallet: wallet, chain: chainAsset.chain)
        }

        if isUniversalWalletIroha(chainAsset.chain) {
            return IrohaTransferService(wallet: wallet, chain: chainAsset.chain)
        }

        if chainAsset.chain.isTonCompatibilityChain {
            guard tonSendReleasePolicy.isEnabled else {
                throw UniversalWalletSendRoutingError.tonProductionSendDisabled
            }
            let chainId = chainAsset.chain.chainId.lowercased()
            guard !(chainAsset.chain.options ?? []).contains(.testnet),
                  chainId == TonChainSelection.mainnetChainId ||
                  chainId == UniversalWalletRegistry.tonMainnetRegistryEntry.chainId ||
                  chainId == UniversalWalletRegistry.tonMainnetRegistryEntry.id
            else {
                throw UniversalWalletSendRoutingError.unsupported(chainId: chainAsset.chain.chainId)
            }
            guard chainAsset.isNative,
                  chainAsset.asset.isNative,
                  chainAsset.asset.isUtility,
                  chainAsset.asset.id == UniversalWalletRegistry.tonNativeAssetId ||
                  chainAsset.asset.id.uppercased() == "TON",
                  chainAsset.asset.symbol.uppercased() == "TON",
                  chainAsset.asset.precision == 9,
                  chainAsset.asset.type == nil || chainAsset.asset.type == .normal
            else {
                throw UniversalWalletSendRoutingError.unsupported(
                    chainId: "\(chainAsset.chain.chainId)/\(chainAsset.asset.id)"
                )
            }

            let remote: TonTransferRemoteProtocol
            if let tonRemote {
                remote = tonRemote
            } else {
                let chainRegistry = ChainRegistryFacade.sharedRegistry as! ChainRegistry
                let factory = try chainRegistry.getTonApiClientFactory(for: chainAsset.chain)
                guard factory.serverURL == ChainRegistry.resolveTonNode(for: chainAsset.chain)?.url else {
                    throw UniversalWalletSendRoutingError.unsupported(chainId: chainAsset.chain.chainId)
                }
                remote = TonAPIRemoteClient(factory: factory)
            }

            #if DEBUG
                if let tonPendingCoordinator {
                    return TonTransferService(
                        wallet: wallet,
                        chain: chainAsset.chain,
                        remote: remote,
                        mnemonicProvider: tonMnemonicProvider,
                        pendingCoordinator: tonPendingCoordinator
                    )
                }
            #endif

            return TonTransferService(
                wallet: wallet,
                chain: chainAsset.chain,
                remote: remote,
                mnemonicProvider: tonMnemonicProvider
            )
        }

        if chainAsset.chain.chainBaseType == .substrate {
            guard let nativeRuntimeService = (ChainRegistryFacade.sharedRegistry as ChainRegistryProtocol).getRuntimeProvider(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let chainRegistryConcrete = ChainRegistryFacade.sharedRegistry as! ChainRegistry
            let connection = try chainRegistryConcrete.getSubstrateConnection(for: chainAsset.chain)
            let operationManager = OperationManagerFacade.sharedManager

            let extrinsicService = SSFExtrinsicKit.ExtrinsicService(
                accountId: accountResponse.accountId,
                chainFormat: chainAsset.chain.chainFormat.asSfCrypto(),
                cryptoType: accountResponse.cryptoType,
                runtimeRegistry: nativeRuntimeService,
                engine: connection,
                operationManager: operationManager
            )
            let secretKey = try fetchSecretKey(for: chainAsset.chain, accountResponse: accountResponse)
            let signer = SubstrateTransactionSigner(
                publicKeyData: accountResponse.publicKey,
                secretKeyData: secretKey,
                cryptoType: accountResponse.cryptoType
            )

            let callFactory = SubstrateCallFactoryDefault(runtimeService: nativeRuntimeService)
            return SubstrateTransferService(extrinsicService: extrinsicService, callFactory: callFactory, signer: signer)
        }

        if chainAsset.chain.chainBaseType == .ethereum {
            let secretKey = try fetchSecretKey(for: chainAsset.chain, accountResponse: accountResponse)

            guard let address = accountResponse.toAddress() else {
                throw ConvenienceError(error: "Cannot fetch address from chain account")
            }

            guard let ws = ChainRegistryFacade.sharedRegistry.getEthereumConnection(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            return EthereumTransferService(
                ws: ws,
                privateKey: try EthereumPrivateKey(privateKey: Array(secretKey)),
                senderAddress: address
            )
        }

        throw UniversalWalletSendRoutingError.unsupported(chainId: chainAsset.chain.chainId)
    }

    private func isUniversalWalletBitcoin(_ chain: ChainModel) -> Bool {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId,
             UniversalWalletRegistry.bitcoinMainnet.id,
             UniversalWalletRegistry.bitcoinTestnet.chainId,
             UniversalWalletRegistry.bitcoinTestnet.id:
            return true
        default:
            return false
        }
    }

    private func isUniversalWalletIroha(_ chain: ChainModel) -> Bool {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.taira.chainId,
             UniversalWalletRegistry.taira.id,
             UniversalWalletRegistry.nexus.chainId,
             UniversalWalletRegistry.nexus.id:
            return true
        default:
            return false
        }
    }

    private func isUniversalWalletSolana(_ chain: ChainModel) -> Bool {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.solanaMainnet.chainId,
             UniversalWalletRegistry.solanaMainnet.id,
             UniversalWalletRegistry.solanaDevnet.chainId,
             UniversalWalletRegistry.solanaDevnet.id:
            return true
        default:
            return false
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
        let settingsRepository: CoreDataRepository<PolkaswapRemoteSettings, SSFAssetManagmentStorage.CDPolkaswapRemoteSettings> =
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
