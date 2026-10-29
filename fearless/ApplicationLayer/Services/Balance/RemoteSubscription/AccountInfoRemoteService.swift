import Foundation
import SSFStorageQueryKit
import SSFChainRegistry
import SSFNetwork
import SSFModels
import SSFUtils
import RobinHood
import BigInt
import IrohaCrypto
import SoraKeystore

protocol AccountInfoRemoteService {
    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?]

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo?
}

protocol AccountInfoLastKnownBalanceProviding {
    func lastKnownAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) -> [ChainAssetId: AccountInfo?]
}

/// A network scan that could not read every balance, for example an EVM token whose call reverts or a network with no
/// working node. The scan failed, so the network keeps its "update failed" attention, but the balances it did read
/// are fresh: they are in `accountInfos` (none when nothing was read), keyed as a full scan's are. The assets it could
/// not read are left out of it, never reported as no balance.
struct IncompleteAccountInfosError: Error {
    let accountInfos: [ChainAssetId: AccountInfo?]
    let unreadChainAssetIds: Set<ChainAssetId>
}

struct RemoteAccountInfoUpdatedEvent: EventProtocol {
    let walletId: MetaAccountId
    let chainId: ChainModel.Id

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRemoteAccountInfoUpdated(event: self)
    }
}

/// Durable last-known balances for remote ecosystems that do not use the
/// Substrate account-info repository. Values are keyed by wallet + AssetKey;
/// display symbols never participate. A failed scan only reads this store and
/// never writes zero into it.
enum RemoteLastKnownBalanceStore {
    private static let prefix = "portfolio.remote.last_known_balance"
    private static let lock = NSLock()

    static func save(
        _ accountInfos: [ChainAssetId: AccountInfo?],
        chain: ChainModel,
        walletId: MetaAccountId,
        userDefaults: UserDefaults = .standard
    ) {
        lock.lock()

        chain.chainAssets.forEach { chainAsset in
            guard let wrapped = accountInfos[chainAsset.chainAssetId],
                  let accountInfo = wrapped else {
                // Nil means unsupported or malformed, not an authoritative
                // zero. Successful scanners materialize omissions as zero.
                return
            }
            // What the wallet owns, not only what it can send this minute: a Bitcoin payment
            // waiting for its first confirmation must not vanish from a retained balance.
            userDefaults.set(
                accountInfo.data.total.description,
                forKey: key(walletId: walletId, assetKey: chainAsset.assetKey)
            )
        }
        lock.unlock()

        EventCenter.shared.notify(
            with: RemoteAccountInfoUpdatedEvent(
                walletId: walletId,
                chainId: chain.chainId
            )
        )
    }

    static func load(
        chain: ChainModel,
        walletId: MetaAccountId,
        userDefaults: UserDefaults = .standard
    ) -> [ChainAssetId: AccountInfo?] {
        lock.lock()
        defer { lock.unlock() }

        return Dictionary(uniqueKeysWithValues: chain.chainAssets.compactMap { chainAsset in
            guard let raw = userDefaults.string(
                forKey: key(walletId: walletId, assetKey: chainAsset.assetKey)
            ), let amount = BigUInt(raw, radix: 10) else {
                return nil
            }
            return (chainAsset.chainAssetId, Optional(AccountInfo(ethBalance: amount)))
        })
    }

    private static func key(walletId: MetaAccountId, assetKey: AssetKey) -> String {
        [prefix, walletId, assetKey.ecosystem, assetKey.chainId, assetKey.assetId]
            .joined(separator: ":")
    }
}

protocol SolanaBalanceSyncing {
    func balances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL: String?,
        includeTokenMetadata: Bool
    ) async throws -> SolanaBalanceSyncResult

    /// The portfolio's read: SOL even when the token accounts cannot be read, in which case
    /// the result says so (`tokenBalancesUnavailable`) instead of reporting no tokens.
    func portfolioBalances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork
    ) async throws -> SolanaBalanceSyncResult
}

extension SolanaBalanceSyncing {
    func portfolioBalances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork
    ) async throws -> SolanaBalanceSyncResult {
        try await balances(wallet: wallet, network: network, baseURL: nil, includeTokenMetadata: true)
    }
}

extension SolanaBalanceSync: SolanaBalanceSyncing {}

/// `baseURL` named the SORA indexer; the JSON-RPC reader starts from the top of its own node
/// list instead, and token metadata is not on chain, so both are ignored.
extension SolanaRpcBalanceSync: SolanaBalanceSyncing {
    func balances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL _: String?,
        includeTokenMetadata _: Bool
    ) async throws -> SolanaBalanceSyncResult {
        try await balances(wallet: wallet, network: network)
    }

    func portfolioBalances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork
    ) async throws -> SolanaBalanceSyncResult {
        try await portfolioBalances(wallet: wallet, network: network, rpcURL: nil)
    }
}

protocol BitcoinBalanceSyncing {
    func balance(
        mnemonic: String,
        passphrase: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String?,
        gapLimit: Int?,
        maxLookahead: Int
    ) async throws -> BitcoinBalanceSyncResult

    func balance(
        address: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String?
    ) async throws -> BitcoinAddressBalanceResult
}

extension BitcoinBalanceSync: BitcoinBalanceSyncing {}

extension BitcoinBalanceSyncing {
    func balance(
        address _: String,
        network _: BitcoinKeyDerivation.Network,
        baseURL _: String?
    ) async throws -> BitcoinAddressBalanceResult {
        throw ConvenienceError(error: "Direct Bitcoin address discovery is unavailable")
    }
}

protocol UniversalWalletMnemonicProviding {
    func mnemonic(for wallet: MetaAccountModel, chain: ChainModel) throws -> String?
    func tonSigningCredentials(for wallet: MetaAccountModel, chain: ChainModel) throws -> TonSigningCredentials
}

extension UniversalWalletMnemonicProviding {
    func tonSigningCredentials(for wallet: MetaAccountModel, chain: ChainModel) throws -> TonSigningCredentials {
        guard let mnemonic = try mnemonic(for: wallet, chain: chain) else { throw TonSendServiceError.invalidAccount }
        return TonSigningCredentials(mnemonic: mnemonic)
    }
}

protocol BitcoinMnemonicProviding: UniversalWalletMnemonicProviding {}

protocol UniversalWalletRootMnemonicProviding {
    func rootMnemonic(for wallet: MetaAccountModel) throws -> String?
}

final class KeychainUniversalWalletMnemonicProvider:
    BitcoinMnemonicProviding,
    UniversalWalletRootMnemonicProviding {
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol = Keychain()) {
        self.keystore = keystore
    }

    func tonSigningCredentials(for wallet: MetaAccountModel, chain: ChainModel) throws -> TonSigningCredentials {
        if let legacy = wallet.legacyTonAccount, chain.isTonCompatibilityChain {
            return try legacy.signingCredentials(keystore: keystore, metaId: wallet.metaId)
        }
        guard let mnemonic = try mnemonic(for: wallet, chain: chain) else { throw TonSendServiceError.invalidAccount }
        return TonSigningCredentials(mnemonic: mnemonic)
    }

    func mnemonic(for wallet: MetaAccountModel, chain: ChainModel) throws -> String? {
        if let legacy = wallet.legacyTonAccount, chain.isTonCompatibilityChain {
            return try legacy.mnemonic(from: keystore.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))).toString()
        }
        let accountResponse = wallet.fetch(for: chain.accountRequest())

        let rootResult = Result { try rootMnemonic(for: wallet) }
        if let rootMnemonic = try? rootResult.get() {
            guard let accountResponse, accountResponse.isChainAccount else {
                return rootMnemonic
            }

            if mnemonicMatches(
                rootMnemonic,
                chainId: chain.chainId,
                publicKey: accountResponse.publicKey
            ) {
                return rootMnemonic
            }
        }

        // Compatibility only for accounts created by older releases with a
        // chain-specific phrase. New provisioning never writes this entropy.
        if accountResponse?.isChainAccount == true,
           let accountMnemonic = try mnemonicIfPresent(
               metaId: wallet.metaId,
               accountId: accountResponse?.accountId
           ), mnemonicMatches(
               accountMnemonic,
               chainId: chain.chainId,
               publicKey: accountResponse?.publicKey
           ) {
            return accountMnemonic
        }

        // A root read/format failure stays an error unless independently verified
        // historical child material above was available for this exact account.
        if case let .failure(error) = rootResult {
            throw error
        }
        return nil
    }

    func rootMnemonic(for wallet: MetaAccountModel) throws -> String? {
        guard wallet.substrateAccountId != nil else { return nil }
        if let rootMnemonic = try mnemonicIfPresent(
            metaId: wallet.metaId,
            accountId: nil
        ) {
            return rootMnemonic
        }

        guard try usesRawWalletSeedBridge(metaId: wallet.metaId),
              let walletSeed = try walletSeedIfPresent(metaId: wallet.metaId)
        else {
            return nil
        }

        return try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
    }

    private func mnemonicIfPresent(
        metaId: MetaAccountId,
        accountId: AccountId?
    ) throws -> String? {
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(
            metaId,
            accountId: accountId
        )

        do {
            let entropy = try keystore.fetchKey(for: entropyTag)
            return try IRMnemonicCreator().mnemonic(fromEntropy: entropy).toString()
        } catch KeystoreError.noKeyFound {
            return nil
        }
    }

    private func walletSeedIfPresent(metaId: MetaAccountId) throws -> Data? {
        let seedTag = KeystoreTagV2.substrateSeedTagForMetaId(metaId)

        do {
            return try keystore.fetchKey(for: seedTag)
        } catch KeystoreError.noKeyFound {
            return nil
        }
    }

    private func usesRawWalletSeedBridge(metaId: MetaAccountId) throws -> Bool {
        let sourceTag = KeystoreTagV2.universalWalletSecretSourceTagForMetaId(metaId)

        do {
            let source = try keystore.fetchKey(for: sourceTag)
            return String(data: source, encoding: .utf8) == UniversalWalletSeedBridge.contract
        } catch KeystoreError.noKeyFound {
            return false
        }
    }

    private func mnemonicMatches(
        _ mnemonic: String,
        chainId: ChainModel.Id,
        publicKey: Data?
    ) -> Bool {
        guard let publicKey else {
            return false
        }

        let derivedPublicKey: Data?
        switch UniversalWalletChainAccountSupport.canonicalChainId(for: chainId) {
        case UniversalWalletRegistry.bitcoinMainnet.chainId:
            derivedPublicKey = try? BitcoinKeyDerivation.deriveAccount(
                mnemonic: mnemonic,
                network: .mainnet
            ).publicKey
        case UniversalWalletRegistry.bitcoinTestnet.chainId:
            derivedPublicKey = try? BitcoinKeyDerivation.deriveAccount(
                mnemonic: mnemonic,
                network: .testnet
            ).publicKey
        case UniversalWalletRegistry.solanaMainnet.chainId,
             UniversalWalletRegistry.solanaDevnet.chainId:
            derivedPublicKey = try? SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic).publicKey
        case UniversalWalletRegistry.tonMainnetRegistryEntry.chainId:
            derivedPublicKey = try? TonKeyDerivation.deriveAccount(mnemonic: mnemonic).publicKey
        case UniversalWalletRegistry.taira.chainId,
             UniversalWalletRegistry.nexus.chainId:
            derivedPublicKey = try? IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic).publicKey
        default:
            return false
        }

        return derivedPublicKey == publicKey
    }
}

typealias KeychainBitcoinMnemonicProvider = KeychainUniversalWalletMnemonicProvider

final class AccountInfoRemoteServiceDefault: AccountInfoRemoteService {
    private enum ChainKind {
        case substrate
        case ethereum
        case ton
        case bitcoin(UniversalWalletRegistry.BitcoinNetwork)
        case solana(UniversalWalletRegistry.SolanaNetwork)
        case iroha(UniversalWalletRegistry.IrohaNetwork)
    }

    private let ethereumRemoteBalanceFetching: AccountInfoFetchingProtocol?
    private let tonRemoteBalanceFetching: AccountInfoRemoteService?
    private let bitcoinBalanceSync: BitcoinBalanceSyncing?
    private let bitcoinMnemonicProvider: BitcoinMnemonicProviding
    private let solanaBalanceSync: SolanaBalanceSyncing?
    private let irohaToriiClient: IrohaToriiClientProtocol?
    private let dynamicAssetCatalogInjector: DynamicAssetCatalogInjecting?
    private let storagePerformer: SSFStorageQueryKit.StorageRequestPerformer

    init(
        ethereumRemoteBalanceFetching: AccountInfoFetchingProtocol? = nil,
        tonRemoteBalanceFetching: AccountInfoRemoteService? = nil,
        bitcoinBalanceSync: BitcoinBalanceSyncing? = nil,
        bitcoinMnemonicProvider: BitcoinMnemonicProviding = KeychainBitcoinMnemonicProvider(),
        solanaBalanceSync: SolanaBalanceSyncing? = nil,
        irohaToriiClient: IrohaToriiClientProtocol? = IrohaToriiClient(),
        dynamicAssetCatalogInjector: DynamicAssetCatalogInjecting? = nil,
        storagePerformer: SSFStorageQueryKit.StorageRequestPerformer
    ) {
        self.ethereumRemoteBalanceFetching = ethereumRemoteBalanceFetching
        self.tonRemoteBalanceFetching = tonRemoteBalanceFetching
        self.bitcoinBalanceSync = bitcoinBalanceSync
        self.bitcoinMnemonicProvider = bitcoinMnemonicProvider
        self.solanaBalanceSync = solanaBalanceSync
        self.irohaToriiClient = irohaToriiClient
        self.dynamicAssetCatalogInjector = dynamicAssetCatalogInjector
        self.storagePerformer = storagePerformer
    }

    // MARK: - AccountInfoStorageService

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        switch chainKind(for: chain) {
        case .ethereum:
            guard wallet.fetch(for: chain.accountRequest())?.accountId != nil else {
                return emptyAccountInfos(for: chain)
            }
            return try await fetchEthereum(for: chain, wallet: wallet)
        case .ton:
            guard let tonRemoteBalanceFetching else {
                throw ConvenienceError(error: "TON remote fetching unavailable")
            }
            return try await tonRemoteBalanceFetching.fetchAccountInfos(for: chain, wallet: wallet)
        case let .bitcoin(network):
            return try await fetchBitcoin(for: chain, wallet: wallet, network: network)
        case let .solana(network):
            return try await fetchSolana(for: chain, wallet: wallet, network: network)
        case let .iroha(network):
            return try await fetchIroha(for: chain, wallet: wallet, network: network)
        case .substrate:
            guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
                return emptyAccountInfos(for: chain)
            }
            return try await fetchSubstrate(for: chain, accountId: accountId)
        }
    }

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo? {
        switch chainKind(for: chainAsset.chain) {
        case .ethereum:
            guard let ethereumRemoteBalanceFetching,
                  let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return nil
            }
            let response = try await ethereumRemoteBalanceFetching.fetch(for: chainAsset, accountId: accountId)
            return response.1
        case .ton:
            guard let tonRemoteBalanceFetching else {
                throw ConvenienceError(error: "TON remote fetching unavailable")
            }
            return try await tonRemoteBalanceFetching.fetchAccountInfo(for: chainAsset, wallet: wallet)
        case let .bitcoin(network):
            let map = try await fetchBitcoin(for: chainAsset.chain, wallet: wallet, network: network)
            return map[chainAsset.chainAssetId] ?? nil
        case let .solana(network):
            // Send, Confirm and the asset screen show one balance and may spend it: SOL needs
            // only its own read, a token needs its token accounts read now.
            let purpose: SolanaBalancePurpose = isSupportedNativeSolanaAsset(chainAsset.asset, network: network)
                ? .nativeBalance
                : .tokenBalance
            let map = try await fetchSolana(for: chainAsset.chain, wallet: wallet, network: network, purpose: purpose)
            return map[chainAsset.chainAssetId] ?? nil
        case let .iroha(network):
            let map = try await fetchIroha(for: chainAsset.chain, wallet: wallet, network: network)
            return map[chainAsset.chainAssetId] ?? nil
        case .substrate:
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return nil
            }
            let request = createSubstrateRequest(for: chainAsset, accountId: accountId)
            let response = try await storagePerformer.perform([request], chain: chainAsset.chain)
            let map = try createSubstrateMap(from: response, chain: chainAsset.chain)
            let accountInfo = map[chainAsset.chainAssetId] ?? nil
            return accountInfo
        }
    }

    private func chainKind(for chain: ChainModel) -> ChainKind {
        if chain.isTonCompatibilityChain {
            return .ton
        }

        if let network = bitcoinNetwork(for: chain) {
            return .bitcoin(network)
        }

        if let network = solanaNetwork(for: chain) {
            return .solana(network)
        }

        if let network = irohaNetwork(for: chain) {
            return .iroha(network)
        }

        if chain.chainBaseType == .ethereum {
            return .ethereum
        }

        return .substrate
    }

    private func bitcoinNetwork(for chain: ChainModel) -> UniversalWalletRegistry.BitcoinNetwork? {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinMainnet.id:
            return UniversalWalletRegistry.bitcoinMainnet
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return UniversalWalletRegistry.bitcoinTestnet
        default:
            return nil
        }
    }

    private func solanaNetwork(for chain: ChainModel) -> UniversalWalletRegistry.SolanaNetwork? {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id:
            return UniversalWalletRegistry.solanaMainnet
        case UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return UniversalWalletRegistry.solanaDevnet
        default:
            return nil
        }
    }

    private func irohaNetwork(for chain: ChainModel) -> UniversalWalletRegistry.IrohaNetwork? {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.taira.id:
            return UniversalWalletRegistry.taira
        case UniversalWalletRegistry.nexus.chainId, UniversalWalletRegistry.nexus.id:
            return UniversalWalletRegistry.nexus
        default:
            return nil
        }
    }

    private func emptyAccountInfos(for chain: ChainModel) -> [ChainAssetId: AccountInfo?] {
        Dictionary(uniqueKeysWithValues: chain.chainAssets.map { ($0.chainAssetId, AccountInfo?.none) })
    }

    // MARK: - Private substrate methods

    private func fetchSubstrate(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetId: AccountInfo?] {
        let requests = chain.chainAssets.map { createSubstrateRequest(for: $0, accountId: accountId) }
        let result = try await storagePerformer.perform(requests, chain: chain)
        let map = try createSubstrateMap(from: result, chain: chain)
        return map
    }

    private func createSubstrateMap(
        from result: [MixStorageResponse],
        chain: ChainModel
    ) throws -> [ChainAssetId: AccountInfo?] {
        try result.reduce([ChainAssetId: AccountInfo?]()) { part, response in
            var partial = part
            let components = response.request.requestId.split(separator: ":", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return partial }
            let id = ChainAssetId(chainId: components[0], assetId: components[1])

            let accountInfo = try mapAccountInfo(response: response, chain: chain)
            partial[id] = accountInfo

            return partial
        }
    }

    private func mapAccountInfo(response: MixStorageResponse, chain: ChainModel) throws -> AccountInfo? {
        guard let json = response.json else {
            return nil
        }

        guard let registry = AccountInfoStorageResponseValueRegistry(rawValue: response.request.responseTypeRegistry) else {
            throw ConvenienceError(error: "Response type not register")
        }

        var accountInfo: AccountInfo?
        switch registry {
        case .accountInfo:
            accountInfo = try json.map(to: AccountInfo.self)
        case .orml:
            let ormlAccountInfo = try json.map(to: OrmlAccountInfo.self)
            accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
        case .equilibrium:
            let eqAccountInfo = try json.map(to: EquilibriumAccountInfo.self)
            let map = eqAccountInfo.data.info?.mapBalances()
            let comps = response.request.requestId.split(separator: ":", maxSplits: 1).map(String.init)
            guard comps.count == 2 else { return nil }
            let chainAssetId = ChainAssetId(chainId: comps[0], assetId: comps[1])
            guard let chainAsset = chain.chainAssets.first(where: { $0.chainAssetId == chainAssetId }) else {
                return nil
            }
            guard let currencyId = chainAsset.asset.currencyId else {
                return nil
            }

            let balance = map?[currencyId]
            accountInfo = AccountInfo(equilibriumFree: balance)
        case .asset:
            let assetAccountInfo = try json.map(to: AssetAccount.self)
            accountInfo = AccountInfo(assetAccount: assetAccountInfo)
        }

        return accountInfo
    }

    private func createSubstrateRequest(for chainAsset: ChainAsset, accountId: AccountId) -> any MixStorageRequest {
        if chainAsset.chain.isEquilibrium || chainAsset.chain.knownChainEquivalent == .genshiro {
            let request = EquilibriumAccountInfotorageRequest(
                parametersType: .encodable(param: accountId),
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        }
        switch chainAsset.currencyId {
        case .soraAsset:
            if chainAsset.isUtility {
                let request = AccountInfoStorageRequest(
                    parametersType: .encodable(param: accountId),
                    storagePath: chainAsset.storagePath,
                    requestId: chainAsset.chainAssetId.id
                )
                return request
            } else {
                let params: [[any SSFStorageQueryKit.NMapKeyParamProtocol]] = [
                    [NMapKeyParam(value: accountId)],
                    [NMapKeyParam(value: chainAsset.currencyId)]
                ]
                let request = OrmlAccountInfoStorageRequest(
                    parametersType: .nMap(params: params),
                    storagePath: chainAsset.storagePath,
                    requestId: chainAsset.chainAssetId.id
                )
                return request
            }
        case .equilibrium:
            let request = EquilibriumAccountInfotorageRequest(
                parametersType: .encodable(param: accountId),
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        case .assets:
            let params: [[any SSFStorageQueryKit.NMapKeyParamProtocol]] = [
                [NMapKeyParam(value: chainAsset.currencyId)],
                [NMapKeyParam(value: accountId)]
            ]
            let request = AssetAccountStorageRequest(
                parametersType: .nMap(params: params),
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        case .none:
            let parametersType: MixStorageRequestParametersType
            if chainAsset.chain.chainId == Chain.reef.genesisHash || chainAsset.chain.chainId == Chain.scuba.genesisHash {
                parametersType = .encodable(param: accountId.toHexString())
            } else {
                parametersType = .encodable(param: accountId)
            }
            let request = AccountInfoStorageRequest(
                parametersType: parametersType,
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        default:
            let params: [[any SSFStorageQueryKit.NMapKeyParamProtocol]] = [
                [NMapKeyParam(value: accountId)],
                [NMapKeyParam(value: chainAsset.currencyId)]
            ]
            let request = OrmlAccountInfoStorageRequest(
                parametersType: .nMap(params: params),
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        }
    }

    // MARK: - Private ethereum methods

    private func fetchEthereum(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        guard let ethereumRemoteBalanceFetching else {
            throw ConvenienceError(error: "Ethereum remote fetching unavailable")
        }
        let chainAsset = chain.chainAssets
        let response = try await ethereumRemoteBalanceFetching.fetch(for: chainAsset, wallet: wallet)
        let mapped = response.map {
            ($0.key.chainAssetId, $0.value)
        }
        let map = Dictionary(uniqueKeysWithValues: mapped)
        // The fetcher leaves out every asset it could not read, so one failed asset fails the scan without taking the
        // balances read with it.
        let unread = Set(chainAsset.map(\.chainAssetId)).subtracting(map.keys)
        guard unread.isEmpty else {
            throw IncompleteAccountInfosError(accountInfos: map, unreadChainAssetIds: unread)
        }
        return map
    }

    // MARK: - Private bitcoin methods

    private func fetchBitcoin(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        network: UniversalWalletRegistry.BitcoinNetwork
    ) async throws -> [ChainAssetId: AccountInfo?] {
        var accountInfos = emptyAccountInfos(for: chain)

        guard let bitcoinBalanceSync else {
            throw ConvenienceError(error: "Bitcoin discovery is unavailable")
        }
        guard let mnemonic = try bitcoinMnemonicProvider.mnemonic(for: wallet, chain: chain) else {
            guard let address = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
                throw ConvenienceError(error: "Bitcoin account address is unavailable")
            }
            let result = try await bitcoinBalanceSync.balance(
                address: address,
                network: bitcoinKeyDerivationNetwork(for: network),
                baseURL: bitcoinBalanceBaseURL(for: network)
            )
            NetworkScanStateStore.markSuccess(
                for: chain,
                coverage: .limited,
                walletId: wallet.metaId
            )

            chain.chainAssets.forEach { chainAsset in
                guard isSupportedNativeBitcoinAsset(chainAsset.asset, network: network),
                      result.totalSats >= 0 else {
                    return
                }
                accountInfos[chainAsset.chainAssetId] = AccountInfo(
                    ethBalance: BigUInt(UInt64(result.totalSats))
                )
            }
            RemoteLastKnownBalanceStore.save(
                accountInfos,
                chain: chain,
                walletId: wallet.metaId
            )
            return accountInfos
        }

        do {
            let keyNetwork = bitcoinKeyDerivationNetwork(for: network)
            let indexerNetwork: BitcoinIndexerNetwork = keyNetwork == .mainnet
                ? .mainnet
                : .testnet
            let baseURL = bitcoinBalanceBaseURL(for: network)
            let cacheKey = BitcoinWalletBalanceCache.Key(
                walletId: wallet.metaId,
                network: indexerNetwork,
                baseURL: baseURL,
                gapLimit: network.defaultGapLimit,
                maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
            )
            let result = try await BitcoinWalletBalanceCache.shared.value(
                for: cacheKey
            ) {
                try await bitcoinBalanceSync.balance(
                    mnemonic: mnemonic,
                    passphrase: "",
                    network: keyNetwork,
                    baseURL: baseURL,
                    gapLimit: network.defaultGapLimit,
                    maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
                )
            }
            NetworkScanStateStore.markSuccess(
                for: chain,
                coverage: .complete,
                walletId: wallet.metaId
            )

            chain.chainAssets.forEach { chainAsset in
                accountInfos[chainAsset.chainAssetId] = bitcoinAccountInfo(
                    for: chainAsset,
                    network: network,
                    balanceResult: result
                )
            }
            RemoteLastKnownBalanceStore.save(
                accountInfos,
                chain: chain,
                walletId: wallet.metaId
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }

        return accountInfos
    }

    private func bitcoinKeyDerivationNetwork(
        for network: UniversalWalletRegistry.BitcoinNetwork
    ) -> BitcoinKeyDerivation.Network {
        network == UniversalWalletRegistry.bitcoinTestnet ? .testnet : .mainnet
    }

    private func bitcoinBalanceBaseURL(
        for network: UniversalWalletRegistry.BitcoinNetwork
    ) -> String {
        let indexerNetwork: BitcoinIndexerNetwork = network == UniversalWalletRegistry.bitcoinTestnet
            ? .testnet
            : .mainnet
        return indexerNetwork.defaultBaseURL.absoluteString
    }

    private func bitcoinAccountInfo(
        for chainAsset: ChainAsset,
        network: UniversalWalletRegistry.BitcoinNetwork,
        balanceResult: BitcoinBalanceSyncResult
    ) -> AccountInfo? {
        guard
            isSupportedNativeBitcoinAsset(chainAsset.asset, network: network),
            balanceResult.totalSats >= 0
        else {
            return nil
        }

        // The portfolio counts everything the wallet owns; Send may only offer confirmed coins,
        // because those are the only ones the planner selects. The difference (an incoming
        // payment or the wallet's own change still waiting for a block) is carried as frozen.
        return AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(
                free: BigUInt(UInt64(balanceResult.totalSats)),
                reserved: .zero,
                frozen: BigUInt(UInt64(balanceResult.pendingSats))
            )
        )
    }

    private func isSupportedNativeBitcoinAsset(
        _ asset: AssetModel,
        network: UniversalWalletRegistry.BitcoinNetwork
    ) -> Bool {
        asset.id.uppercased() == network.nativeAsset.id &&
            asset.symbol.uppercased() == network.nativeAsset.symbol &&
            asset.precision == UInt16(network.nativeAsset.decimals) &&
            asset.isNative
    }

    // MARK: - Private solana methods

    /// What a Solana read is for, which decides what may stand in for token accounts that no
    /// node returned.
    private enum SolanaBalancePurpose {
        /// The wallet overview. SOL is refreshed; the scan then fails, so the network says its
        /// balances were not updated, and the overview keeps the token balances it last knew.
        case portfolio
        /// One SOL balance (Send, Confirm, the asset screen): only the SOL read must succeed.
        case nativeBalance
        /// One token balance that may be spent: its token accounts must be read now; nothing
        /// older or zero is reported instead.
        case tokenBalance
    }

    private func fetchSolana(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        network: UniversalWalletRegistry.SolanaNetwork,
        purpose: SolanaBalancePurpose = .portfolio
    ) async throws -> [ChainAssetId: AccountInfo?] {
        var accountInfos = emptyAccountInfos(for: chain)

        guard
            network == UniversalWalletRegistry.solanaMainnet,
            let solanaBalanceSync,
            let address = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet)
        else {
            return accountInfos
        }

        do {
            // Balances come from Solana JSON-RPC; the SORA indexer serves testnet only.
            let result: SolanaBalanceSyncResult
            switch purpose {
            case .tokenBalance:
                result = try await solanaBalanceSync.balances(
                    wallet: address,
                    network: network,
                    baseURL: nil,
                    includeTokenMetadata: true
                )
            case .portfolio, .nativeBalance:
                result = try await solanaBalanceSync.portfolioBalances(wallet: address, network: network)
            }

            if result.tokenBalancesUnavailable {
                // SOL is fresh; no node returned the token accounts.
                var nativeInfos: [ChainAssetId: AccountInfo?] = [:]
                chain.chainAssets.filter { isSupportedNativeSolanaAsset($0.asset, network: network) }.forEach {
                    nativeInfos[$0.chainAssetId] = solanaAccountInfo(for: $0, network: network, balanceResult: result)
                }
                switch purpose {
                case .nativeBalance:
                    nativeInfos.forEach { accountInfos[$0.key] = $0.value }
                    return accountInfos
                case .portfolio:
                    // Only SOL joins the balances last known, so a newer complete scan's token
                    // amounts are never written over. Failing the scan keeps its staleness and
                    // "update failed" attention in force for the tokens that were not read.
                    RemoteLastKnownBalanceStore.save(nativeInfos, chain: chain, walletId: wallet.metaId)
                    throw SolanaBalanceSyncError.tokenBalancesUnavailable
                case .tokenBalance:
                    throw SolanaBalanceSyncError.tokenBalancesUnavailable
                }
            }
            NetworkScanStateStore.markSuccess(
                for: chain,
                coverage: .complete,
                walletId: wallet.metaId
            )

            let discoveredAssets = discoveredSolanaAssets(from: result, chain: chain)
            await dynamicAssetCatalogInjector?.inject(assetModels: discoveredAssets, into: chain)
            let effectiveChainAssets = chain.chainAssets + discoveredAssets.map {
                ChainAsset(chain: chain, asset: $0)
            }

            effectiveChainAssets.forEach { chainAsset in
                accountInfos[chainAsset.chainAssetId] = solanaAccountInfo(
                    for: chainAsset,
                    network: network,
                    balanceResult: result
                )
            }
            RemoteLastKnownBalanceStore.save(
                accountInfos,
                chain: chain,
                walletId: wallet.metaId
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }

        return accountInfos
    }

    private func discoveredSolanaAssets(
        from result: SolanaBalanceSyncResult,
        chain: ChainModel
    ) -> [AssetModel] {
        let registryIds = Set(chain.assets.map(\.id))
        let groupedBalances = Dictionary(grouping: result.tokenBalances) {
            $0.contractAddress ?? $0.assetId
        }

        return groupedBalances.compactMap { mint, balances in
            guard !mint.isEmpty,
                  !registryIds.contains(mint),
                  Set(balances.map(\.decimals)).count == 1,
                  let decimals = balances.first?.decimals,
                  let precision = UInt16(exactly: decimals) else {
                return nil
            }

            var total = BigUInt.zero
            for balance in balances {
                guard let amount = BigUInt(balance.amount) else {
                    return nil
                }
                total += amount
            }
            guard total > .zero else {
                return nil
            }

            let shortMint = shortenedAssetIdentifier(mint)
            let symbol = balances.compactMap { sanitizedAssetText($0.symbol) }.first ?? shortMint
            let name = balances.compactMap { sanitizedAssetText($0.name) }.first ?? symbol
            let asset = AssetModel(
                id: mint,
                name: name,
                symbol: symbol,
                precision: precision,
                icon: nil,
                price: nil,
                fiatDayChange: nil,
                currencyId: mint,
                existentialDeposit: nil,
                color: nil,
                isUtility: false,
                isNative: false,
                staking: nil,
                purchaseProviders: nil,
                type: nil,
                ethereumType: nil,
                priceProvider: nil,
                coingeckoPriceId: nil
            )
            AssetTrustResolver.markUnverified(ChainAsset(chain: chain, asset: asset))
            return asset
        }
    }

    private func solanaAccountInfo(
        for chainAsset: ChainAsset,
        network: UniversalWalletRegistry.SolanaNetwork,
        balanceResult: SolanaBalanceSyncResult
    ) -> AccountInfo? {
        if isSupportedNativeSolanaAsset(chainAsset.asset, network: network) {
            guard balanceResult.nativeBalance.decimals == Int(chainAsset.asset.precision),
                  let amount = BigUInt(balanceResult.nativeBalance.amount) else {
                return nil
            }

            return AccountInfo(ethBalance: amount)
        }

        let balances = balanceResult.tokenBalances.filter {
            $0.assetId == chainAsset.asset.id || $0.contractAddress == chainAsset.asset.id
        }
        guard balances.isNotEmpty else {
            return AccountInfo(ethBalance: .zero)
        }
        guard Set(balances.map(\.decimals)).count == 1,
              balances.first?.decimals == Int(chainAsset.asset.precision) else {
            return nil
        }

        var total = BigUInt.zero
        for balance in balances {
            guard let amount = BigUInt(balance.amount) else {
                return nil
            }
            total += amount
        }

        return AccountInfo(ethBalance: total)
    }

    private func isSupportedNativeSolanaAsset(
        _ asset: AssetModel,
        network: UniversalWalletRegistry.SolanaNetwork
    ) -> Bool {
        asset.id.uppercased() == network.nativeAsset.id &&
            asset.symbol.uppercased() == network.nativeAsset.symbol &&
            asset.precision == UInt16(network.nativeAsset.decimals) &&
            asset.isNative
    }

    private func sanitizedAssetText(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty,
              normalized.count <= 80,
              normalized.rangeOfCharacter(from: .controlCharacters) == nil else {
            return nil
        }

        return normalized
    }

    private func shortenedAssetIdentifier(_ value: String) -> String {
        guard value.count > 12 else {
            return value
        }

        return "\(value.prefix(5))…\(value.suffix(5))"
    }

    // MARK: - Private Iroha methods

    private func fetchIroha(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        network: UniversalWalletRegistry.IrohaNetwork
    ) async throws -> [ChainAssetId: AccountInfo?] {
        var accountInfos = emptyAccountInfos(for: chain)

        guard let irohaToriiClient else {
            throw ConvenienceError(error: "Iroha remote fetching unavailable")
        }
        guard let address = UniversalWalletAccountAddressResolver.address(
            for: chain,
            wallet: wallet
        ) else {
            throw ConvenienceError(error: "Iroha account address is unavailable")
        }

        do {
            let baseURL = irohaBalanceBaseURL(for: chain, network: network)
            let validatesCanonicalTairaXor = shouldValidateCanonicalTairaXor(network: network)
            let tairaXorAliasResolution: IrohaAssetAliasResolution?
            let tairaXorDefinition: IrohaAssetDefinitionListItem?
            if validatesCanonicalTairaXor {
                tairaXorAliasResolution = try await irohaToriiClient.resolveAssetAlias(
                    UniversalWalletRegistry.tairaNativeXorAlias,
                    baseURL: baseURL
                )
                tairaXorDefinition = try await irohaToriiClient.assetDefinition(
                    selector: UniversalWalletRegistry.tairaNativeXorAlias,
                    baseURL: baseURL
                )
            } else {
                tairaXorAliasResolution = nil
                tairaXorDefinition = nil
            }
            var items: [IrohaAccountAssetListItem] = []
            var cursor: String?
            var pageCount = 0
            var seenCursors = Set<String>()
            var seenPageFingerprints = Set<String>()

            repeat {
                guard pageCount < 1000 else {
                    throw ConvenienceError(error: "Iroha account-asset pagination exceeded its safety bound")
                }
                let response = try await irohaToriiClient.accountAssets(
                    accountID: address,
                    baseURL: baseURL,
                    limit: IrohaToriiRoutes.maxLimit,
                    cursor: cursor,
                    network: network
                )
                let fingerprint = response.items.map {
                    [$0.accountID, $0.assetID, $0.asset, $0.quantity, $0.scope]
                        .compactMap { $0 }
                        .joined(separator: "|")
                }.joined(separator: "\n")
                guard response.items.isEmpty || seenPageFingerprints.insert(fingerprint).inserted else {
                    throw ConvenienceError(error: "Iroha account-asset pagination repeated a page")
                }
                items.append(contentsOf: response.items)
                cursor = try nextIrohaCursor(response.nextCursor, seenCursors: &seenCursors)
                pageCount += 1
            } while cursor != nil

            let registryIds = Set(chain.assets.map(\.id))
            let requiredDefinitionIds = Set(items.compactMap { item -> String? in
                let assetId = sanitizedAssetText(item.assetID) ?? item.asset
                guard !registryIds.contains(assetId),
                      (Decimal(string: item.quantity) ?? .zero) > .zero else {
                    return nil
                }
                return assetId
            })
            let definitionsResult = try await fetchIrohaDefinitions(
                requiredAssetIds: requiredDefinitionIds,
                baseURL: baseURL,
                client: irohaToriiClient
            )
            let definitions = [tairaXorDefinition].compactMap { $0 } + definitionsResult.items.filter {
                $0.id != tairaXorDefinition?.id
            }
            if let tairaXorAliasResolution, let tairaXorDefinition {
                try validateCanonicalTairaXor(
                    chain: chain,
                    aliasResolution: tairaXorAliasResolution,
                    definition: tairaXorDefinition
                )
            }
            let discoveredAssets = discoveredIrohaAssets(
                from: items,
                definitions: definitions,
                chain: chain
            )
            await dynamicAssetCatalogInjector?.inject(assetModels: discoveredAssets, into: chain)
            let effectiveChainAssets = chain.chainAssets + discoveredAssets.map {
                ChainAsset(chain: chain, asset: $0)
            }

            effectiveChainAssets.forEach { chainAsset in
                accountInfos[chainAsset.chainAssetId] = irohaAccountInfo(
                    for: chainAsset,
                    address: address,
                    items: items
                )
            }
            RemoteLastKnownBalanceStore.save(
                accountInfos,
                chain: chain,
                walletId: wallet.metaId
            )
            NetworkScanStateStore.markSuccess(
                for: chain,
                coverage: definitionsResult.isComplete ? .complete : .limited,
                walletId: wallet.metaId
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }

        return accountInfos
    }

    private func fetchIrohaDefinitions(
        requiredAssetIds: Set<String>,
        baseURL: String?,
        client: IrohaToriiClientProtocol
    ) async throws -> (items: [IrohaAssetDefinitionListItem], isComplete: Bool) {
        guard requiredAssetIds.isNotEmpty else {
            return ([], true)
        }

        var definitions: [IrohaAssetDefinitionListItem] = []
        var foundIds = Set<String>()
        var seenCursors = Set<String>()
        var seenPageFingerprints = Set<String>()
        var cursor: String?

        for _ in 0 ..< 1000 {
            let response = try await client.assetDefinitions(
                baseURL: baseURL,
                limit: IrohaToriiRoutes.maxLimit,
                cursor: cursor
            )
            let pageIds = response.items.map(\.id)
            let fingerprint = pageIds.joined(separator: "\n")
            guard pageIds.isEmpty || seenPageFingerprints.insert(fingerprint).inserted else {
                throw ConvenienceError(error: "Iroha asset-definition pagination repeated a page")
            }

            definitions.append(contentsOf: response.items)
            foundIds.formUnion(pageIds)
            if requiredAssetIds.isSubset(of: foundIds) {
                return (definitions, true)
            }
            guard let nextCursor = try nextIrohaCursor(response.nextCursor, seenCursors: &seenCursors) else {
                return (definitions, false)
            }
            cursor = nextCursor
        }

        throw ConvenienceError(error: "Iroha asset-definition pagination exceeded its safety bound")
    }

    /// The cursor of the next Torii page, or nil after the last one. A cursor that comes back
    /// a second time means paging makes no progress, so it fails instead of looping.
    private func nextIrohaCursor(
        _ cursor: String?,
        seenCursors: inout Set<String>
    ) throws -> String? {
        guard let cursor, !cursor.isEmpty else {
            return nil
        }
        guard seenCursors.insert(cursor).inserted else {
            throw ConvenienceError(error: "Iroha pagination made no progress")
        }

        return cursor
    }

    private func discoveredIrohaAssets(
        from items: [IrohaAccountAssetListItem],
        definitions: [IrohaAssetDefinitionListItem],
        chain: ChainModel
    ) -> [AssetModel] {
        let registryIds = Set(chain.assets.map(\.id))
        let groupedItems = Dictionary(grouping: items) { item in
            sanitizedAssetText(item.assetID) ?? item.asset
        }

        return groupedItems.compactMap { assetId, heldItems in
            guard !assetId.isEmpty,
                  !registryIds.contains(assetId),
                  heldItems.contains(where: { (Decimal(string: $0.quantity) ?? .zero) > .zero }) else {
                return nil
            }

            let definition = definitions.first { $0.id == assetId }
            let precisionResult = irohaPrecision(
                assetId: assetId,
                definition: definition,
                quantities: heldItems.map(\.quantity),
                chain: chain
            )
            let alias = sanitizedAssetText(definition?.alias) ??
                heldItems.compactMap { sanitizedAssetText($0.assetAlias) }.first
            let name = sanitizedAssetText(definition?.name) ??
                heldItems.compactMap { sanitizedAssetText($0.assetName) }.first ??
                alias ?? shortenedAssetIdentifier(assetId)
            let symbol = alias ?? name
            let asset = AssetModel(
                id: assetId,
                name: name,
                symbol: symbol,
                precision: precisionResult.precision,
                icon: nil,
                price: nil,
                fiatDayChange: nil,
                currencyId: assetId,
                existentialDeposit: nil,
                color: nil,
                isUtility: false,
                isNative: false,
                staking: nil,
                purchaseProviders: nil,
                type: nil,
                ethereumType: nil,
                priceProvider: nil,
                coingeckoPriceId: nil
            )
            let chainAsset = ChainAsset(chain: chain, asset: asset)
            if precisionResult.isMetadataMissing {
                AssetTrustResolver.markMissing(chainAsset)
            } else {
                AssetTrustResolver.markUnverified(chainAsset)
            }
            return asset
        }
    }

    private func irohaPrecision(
        assetId: String,
        definition: IrohaAssetDefinitionListItem?,
        quantities: [String],
        chain: ChainModel
    ) -> (precision: UInt16, isMetadataMissing: Bool) {
        let key = AssetKey(ecosystem: "iroha", chainId: chain.chainId, assetId: assetId)
        if let spec = definition?.spec {
            if let precision = spec.fixedPointAdapterPrecision {
                DynamicAssetPrecisionStore.remember(precision, for: key)
                return (precision, false)
            }

            return (UInt16(IrohaAssetDefinitionSpec.maximumScale), true)
        }

        let metadataPrecision = definition?.metadata.flatMap { metadata in
            ["precision", "decimals", "scale"].compactMap { key in
                metadata[key].flatMap(irohaIntegerValue)
            }.first
        }
        if let metadataPrecision,
           metadataPrecision >= 0,
           let precision = UInt16(exactly: metadataPrecision) {
            DynamicAssetPrecisionStore.remember(precision, for: key)
            return (precision, false)
        }
        if let catalogPrecision = chain.assets.first(where: { $0.id == assetId })?.precision {
            DynamicAssetPrecisionStore.remember(catalogPrecision, for: key)
            return (catalogPrecision, false)
        }
        if let storedPrecision = DynamicAssetPrecisionStore.precision(for: key) {
            return (storedPrecision, true)
        }

        let fractionalDigits = quantities.map { quantity in
            quantity.split(separator: ".", omittingEmptySubsequences: false)[safe: 1]?.count ?? 0
        }.max() ?? 0
        // Iroha account balances are decimal strings. When the definition does
        // not declare a scale, keep an exact fixed-point representation at a
        // conservative scale and mark metadata missing instead of claiming the
        // currently observed fractional length is authoritative.
        let fallbackPrecision = UInt16(clamping: max(18, fractionalDigits))
        DynamicAssetPrecisionStore.remember(fallbackPrecision, for: key)
        return (fallbackPrecision, true)
    }

    private func irohaIntegerValue(_ value: IrohaJSONValue) -> Int? {
        switch value {
        case let .int(value):
            return Int(exactly: value)
        case let .double(value):
            return value.rounded() == value ? Int(exactly: value) : nil
        case let .string(value):
            return Int(value)
        case .bool, .object, .array, .null:
            return nil
        }
    }

    private func irohaBalanceBaseURL(
        for chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork
    ) -> String? {
        if network == UniversalWalletRegistry.taira {
            return network.toriiBaseURL?.absoluteString
        }

        return chain.externalApi?.history?.url.absoluteString ?? network.toriiBaseURL?.absoluteString
    }

    private func shouldValidateCanonicalTairaXor(
        network: UniversalWalletRegistry.IrohaNetwork
    ) -> Bool {
        network == UniversalWalletRegistry.taira
    }

    private func validateCanonicalTairaXor(
        chain: ChainModel,
        aliasResolution: IrohaAssetAliasResolution,
        definition: IrohaAssetDefinitionListItem
    ) throws {
        let assetId = UniversalWalletRegistry.tairaNativeXorAssetDefinitionId
        let alias = UniversalWalletRegistry.tairaNativeXorAlias
        guard aliasResolution.alias == alias,
              aliasResolution.assetDefinitionID == assetId,
              aliasResolution.assetName.lowercased() == "xor",
              aliasResolution.aliasBinding?.alias == alias,
              aliasResolution.aliasBinding?.status == "permanent",
              definition.id == assetId,
              definition.alias == alias,
              definition.name?.lowercased() == "xor",
              definition.spec != nil,
              definition.spec?.scale == nil,
              let chainAsset = chain.assets.first(where: { $0.id == assetId }),
              chainAsset.currencyId == alias,
              chainAsset.precision == UniversalWalletRegistry.tairaNativeXorPrecision,
              chainAsset.isUtility,
              chainAsset.isNative else {
            throw ConvenienceError(
                error: "Taira XOR does not match the reviewed IrohaSwift/Torii contract"
            )
        }
    }

    private func irohaAccountInfo(
        for chainAsset: ChainAsset,
        address: String,
        items: [IrohaAccountAssetListItem]
    ) -> AccountInfo? {
        let amounts = items
            .filter { irohaAccountAsset($0, matchesAddress: address) && irohaAccountAsset($0, matchesAsset: chainAsset.asset) }
            .compactMap { irohaPlanks(from: $0.quantity, precision: chainAsset.asset.precision) }

        guard !amounts.isEmpty else {
            return AccountInfo(ethBalance: .zero)
        }

        let amount = amounts.reduce(BigUInt.zero, +)
        return AccountInfo(ethBalance: amount)
    }

    private func irohaAccountAsset(
        _ item: IrohaAccountAssetListItem,
        matchesAddress address: String
    ) -> Bool {
        guard let accountId = item.accountID, !accountId.isEmpty else {
            return true
        }

        return accountId == address
    }

    private func irohaAccountAsset(
        _ item: IrohaAccountAssetListItem,
        matchesAsset asset: AssetModel
    ) -> Bool {
        let chainAssetIds = [
            asset.id,
            asset.currencyId
        ].compactMap { $0 }

        let itemAssetIds = [
            item.asset,
            item.assetID,
            item.assetName,
            item.assetAlias
        ].compactMap { $0 }

        return itemAssetIds.contains { itemId in
            chainAssetIds.contains(itemId)
        }
    }

    private func irohaPlanks(from quantity: String, precision: UInt16) -> BigUInt? {
        let normalized = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(0|[1-9][0-9]*)(\.[0-9]+)?$"#
        guard normalized.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else {
            return nil
        }

        let integerPart = String(parts[0])
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        guard fractionPart.count <= Int(precision) else {
            return nil
        }

        let paddedFraction = fractionPart.padding(
            toLength: Int(precision),
            withPad: "0",
            startingAt: 0
        )
        return BigUInt(integerPart + paddedFraction)
    }
}

extension AccountInfoRemoteServiceDefault: AccountInfoLastKnownBalanceProviding {
    func lastKnownAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) -> [ChainAssetId: AccountInfo?] {
        RemoteLastKnownBalanceStore.load(chain: chain, walletId: wallet.metaId)
    }
}
