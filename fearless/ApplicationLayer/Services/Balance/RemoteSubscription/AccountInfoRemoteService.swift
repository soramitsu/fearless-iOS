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

enum IrohaAssetConfigurationError: Error, Equatable {
    case invalidNetworkIdentity(String)
    case truncatedDefinitions
    case truncatedBalances
    case nonCanonicalDefinition(String)
    case duplicateDefinition(String)
    case missingDefinition(String)
    case missingScale(String)
    case nativeProfileMismatch(assetId: String, symbol: String, precision: UInt16)
    case precisionMismatch(assetId: String, wallet: UInt16, torii: Int)
    case invalidQuantity(assetId: String, quantity: String, precision: UInt16)
    case invalidAccountAssets(String)
    case balanceOverflow(String)
}

private let maxIrohaNumeric = (BigUInt(1) << 511) - 1

protocol SolanaBalanceSyncing {
    func balances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL: String?,
        includeTokenMetadata: Bool
    ) async throws -> SolanaBalanceSyncResult
}

extension SolanaBalanceSync: SolanaBalanceSyncing {}

protocol BitcoinBalanceSyncing {
    func balance(
        mnemonic: String,
        passphrase: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String?,
        gapLimit: Int?,
        maxLookahead: Int
    ) async throws -> BitcoinBalanceSyncResult
}

extension BitcoinBalanceSync: BitcoinBalanceSyncing {}

protocol UniversalWalletMnemonicProviding {
    func mnemonic(for wallet: MetaAccountModel, chain: ChainModel) throws -> String?
}

protocol BitcoinMnemonicProviding: UniversalWalletMnemonicProviding {}

final class KeychainUniversalWalletMnemonicProvider: BitcoinMnemonicProviding {
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol = Keychain()) {
        self.keystore = keystore
    }

    func mnemonic(for wallet: MetaAccountModel, chain: ChainModel) throws -> String? {
        let accountResponse = wallet.fetch(for: chain.accountRequest())
        var accountIds: [AccountId?] = []

        if accountResponse?.isChainAccount == true {
            accountIds.append(accountResponse?.accountId)
        }

        accountIds.append(nil)

        for accountId in accountIds {
            let entropyTag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId)
            guard let entropy = try? keystore.fetchKey(for: entropyTag) else {
                continue
            }

            return try IRMnemonicCreator().mnemonic(fromEntropy: entropy).toString()
        }

        return nil
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

    private let ethereumRemoteBalanceFetching: AccountInfoFetchingProtocol
    private let tonRemoteBalanceFetching: AccountInfoRemoteService?
    private let bitcoinBalanceSync: BitcoinBalanceSyncing?
    private let bitcoinMnemonicProvider: BitcoinMnemonicProviding
    private let solanaBalanceSync: SolanaBalanceSyncing?
    private let irohaToriiClient: IrohaToriiClientProtocol?
    private let storagePerformer: SSFStorageQueryKit.StorageRequestPerformer

    init(
        ethereumRemoteBalanceFetching: AccountInfoFetchingProtocol,
        tonRemoteBalanceFetching: AccountInfoRemoteService?,
        bitcoinBalanceSync: BitcoinBalanceSyncing? = nil,
        bitcoinMnemonicProvider: BitcoinMnemonicProviding = KeychainBitcoinMnemonicProvider(),
        solanaBalanceSync: SolanaBalanceSyncing? = nil,
        irohaToriiClient: IrohaToriiClientProtocol? = IrohaToriiClient(),
        storagePerformer: SSFStorageQueryKit.StorageRequestPerformer
    ) {
        self.ethereumRemoteBalanceFetching = ethereumRemoteBalanceFetching
        self.tonRemoteBalanceFetching = tonRemoteBalanceFetching
        self.bitcoinBalanceSync = bitcoinBalanceSync
        self.bitcoinMnemonicProvider = bitcoinMnemonicProvider
        self.solanaBalanceSync = solanaBalanceSync
        self.irohaToriiClient = irohaToriiClient
        self.storagePerformer = storagePerformer
    }

    // MARK: - AccountInfoStorageService

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        if UniversalWalletChainAccountSupport.isNonCanonicalIrohaProfile(chain) {
            throw IrohaAssetConfigurationError.invalidNetworkIdentity(chain.chainId)
        }

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
        if UniversalWalletChainAccountSupport.isNonCanonicalIrohaProfile(chainAsset.chain) {
            throw IrohaAssetConfigurationError.invalidNetworkIdentity(chainAsset.chain.chainId)
        }

        switch chainKind(for: chainAsset.chain) {
        case .ethereum:
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
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
            let map = try await fetchSolana(for: chainAsset.chain, wallet: wallet, network: network)
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
        switch chain.chainId {
        case UniversalWalletRegistry.taira.chainId:
            return UniversalWalletRegistry.taira
        case UniversalWalletRegistry.nexus.chainId:
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
        let chainAsset = chain.chainAssets
        let response = try await ethereumRemoteBalanceFetching.fetch(for: chainAsset, wallet: wallet)
        let mapped = response.map {
            ($0.key.chainAssetId, $0.value)
        }
        let map = Dictionary(uniqueKeysWithValues: mapped)
        return map
    }

    // MARK: - Private bitcoin methods

    private func fetchBitcoin(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        network: UniversalWalletRegistry.BitcoinNetwork
    ) async throws -> [ChainAssetId: AccountInfo?] {
        var accountInfos = emptyAccountInfos(for: chain)

        guard
            let bitcoinBalanceSync,
            let mnemonic = try bitcoinMnemonicProvider.mnemonic(for: wallet, chain: chain)
        else {
            return accountInfos
        }

        do {
            let result = try await bitcoinBalanceSync.balance(
                mnemonic: mnemonic,
                passphrase: "",
                network: bitcoinKeyDerivationNetwork(for: network),
                baseURL: bitcoinBalanceBaseURL(for: chain),
                gapLimit: network.defaultGapLimit,
                maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
            )

            chain.chainAssets.forEach { chainAsset in
                accountInfos[chainAsset.chainAssetId] = bitcoinAccountInfo(
                    for: chainAsset,
                    network: network,
                    balanceResult: result
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return accountInfos
        }

        return accountInfos
    }

    private func bitcoinKeyDerivationNetwork(
        for network: UniversalWalletRegistry.BitcoinNetwork
    ) -> BitcoinKeyDerivation.Network {
        network == UniversalWalletRegistry.bitcoinTestnet ? .testnet : .mainnet
    }

    private func bitcoinBalanceBaseURL(for chain: ChainModel) -> String? {
        chain.externalApi?.history?.url.absoluteString
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

        return AccountInfo(ethBalance: BigUInt(UInt64(balanceResult.totalSats)))
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

    private func fetchSolana(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        network: UniversalWalletRegistry.SolanaNetwork
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
            let result = try await solanaBalanceSync.balances(
                wallet: address,
                network: network,
                baseURL: solanaBalanceBaseURL(for: chain),
                includeTokenMetadata: false
            )

            chain.chainAssets.forEach { chainAsset in
                accountInfos[chainAsset.chainAssetId] = solanaAccountInfo(
                    for: chainAsset,
                    network: network,
                    balanceResult: result
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return accountInfos
        }

        return accountInfos
    }

    private func solanaBalanceBaseURL(for chain: ChainModel) -> String? {
        chain.externalApi?.history?.url.absoluteString
    }

    private func solanaAccountInfo(
        for chainAsset: ChainAsset,
        network: UniversalWalletRegistry.SolanaNetwork,
        balanceResult: SolanaBalanceSyncResult
    ) -> AccountInfo? {
        let indexedBalance: UniversalWalletIndexedAssetBalance?
        if isSupportedNativeSolanaAsset(chainAsset.asset, network: network) {
            indexedBalance = balanceResult.nativeBalance
        } else {
            indexedBalance = balanceResult.tokenBalances.first {
                $0.assetId == chainAsset.asset.id || $0.contractAddress == chainAsset.asset.id
            }
        }

        guard
            let indexedBalance,
            indexedBalance.decimals == Int(chainAsset.asset.precision),
            let amount = BigUInt(indexedBalance.amount)
        else {
            return nil
        }

        return AccountInfo(ethBalance: amount)
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

    // MARK: - Private Iroha methods

    private func fetchIroha(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        network: UniversalWalletRegistry.IrohaNetwork
    ) async throws -> [ChainAssetId: AccountInfo?] {
        var accountInfos = emptyAccountInfos(for: chain)

        guard
            let irohaToriiClient,
            let address = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet)
        else {
            return accountInfos
        }

        let baseURL = irohaBalanceBaseURL(for: chain)
        let definitions = try await irohaToriiClient.assetDefinitions(
            baseURL: baseURL,
            limit: IrohaToriiRoutes.maxLimit,
            offset: 0,
            countMode: .bounded
        )
        guard !definitions.hasMore,
              definitions.countMode == IrohaToriiCountMode.bounded.rawValue else {
            throw IrohaAssetConfigurationError.truncatedDefinitions
        }
        let definitionsById = try irohaDefinitionsByCanonicalId(definitions.items)
        let response = try await irohaToriiClient.accountAssets(
            accountID: address,
            baseURL: baseURL,
            limit: IrohaToriiRoutes.maxLimit,
            offset: 0,
            countMode: .bounded,
            asset: nil,
            scope: nil,
            network: network
        )
        guard !response.hasMore,
              response.countMode == IrohaToriiCountMode.bounded.rawValue else {
            throw IrohaAssetConfigurationError.truncatedBalances
        }
        try validateIrohaAccountAssets(response.items, address: address)

        for chainAsset in chain.chainAssets {
            let assetId: String
            do {
                assetId = try IrohaToriiRoutes.normalizeAssetDefinitionId(chainAsset.asset.id)
            } catch {
                throw IrohaAssetConfigurationError.nonCanonicalDefinition(chainAsset.asset.id)
            }
            guard let definition = definitionsById[assetId] else {
                throw IrohaAssetConfigurationError.missingDefinition(assetId)
            }
            let profilePrecision = try irohaProfilePrecision(
                for: chainAsset.asset,
                canonicalAssetId: assetId,
                network: network
            )
            let precision = try irohaPrecision(
                expectedPrecision: profilePrecision,
                definition: definition
            )
            accountInfos[chainAsset.chainAssetId] = try irohaAccountInfo(
                canonicalAssetId: assetId,
                precision: precision,
                response: response
            )
        }

        return accountInfos
    }

    private func irohaBalanceBaseURL(for chain: ChainModel) -> String? {
        chain.externalApi?.history?.url.absoluteString
    }

    private func irohaAccountInfo(
        canonicalAssetId: String,
        precision: UInt16,
        response: IrohaAccountAssetListResponse
    ) throws -> AccountInfo? {
        let matchingItems = response.items.filter {
            $0.asset == canonicalAssetId
        }
        let amounts = try matchingItems.map { item -> BigUInt in
            guard let amount = irohaPlanks(from: item.quantity, precision: precision) else {
                throw IrohaAssetConfigurationError.invalidQuantity(
                    assetId: canonicalAssetId,
                    quantity: item.quantity,
                    precision: precision
                )
            }
            return amount
        }

        guard !amounts.isEmpty else {
            return nil
        }

        let scaleFactor = (0 ..< Int(precision)).reduce(BigUInt(1)) { factor, _ in
            factor * 10
        }
        let maxBalanceInPlanks = maxIrohaNumeric * scaleFactor
        let amount = try amounts.reduce(BigUInt.zero) { total, value in
            guard total <= maxBalanceInPlanks,
                  value <= maxBalanceInPlanks - total else {
                throw IrohaAssetConfigurationError.balanceOverflow(canonicalAssetId)
            }
            return total + value
        }
        return AccountInfo(ethBalance: amount)
    }

    private func validateIrohaAccountAssets(
        _ items: [IrohaAccountAssetListItem],
        address: String
    ) throws {
        var seenAssetScopes = Set<String>()
        for item in items {
            guard item.accountID == address else {
                throw IrohaAssetConfigurationError.invalidAccountAssets("account_id")
            }
            guard item.assetID == nil else {
                throw IrohaAssetConfigurationError.invalidAccountAssets("asset_id")
            }
            let canonicalAsset: String
            do {
                canonicalAsset = try IrohaToriiRoutes.normalizeAssetDefinitionId(item.asset)
            } catch {
                throw IrohaAssetConfigurationError.invalidAccountAssets("asset")
            }
            guard canonicalAsset == item.asset else {
                throw IrohaAssetConfigurationError.invalidAccountAssets("asset")
            }
            guard let scope = item.scope else {
                throw IrohaAssetConfigurationError.invalidAccountAssets("scope")
            }
            let canonicalScope: String
            do {
                canonicalScope = try IrohaToriiRoutes.normalizeAccountAssetScope(scope)
            } catch {
                throw IrohaAssetConfigurationError.invalidAccountAssets("scope")
            }
            guard canonicalScope == scope else {
                throw IrohaAssetConfigurationError.invalidAccountAssets("scope")
            }
            guard seenAssetScopes.insert("\(canonicalAsset)\u{0}\(canonicalScope)").inserted else {
                throw IrohaAssetConfigurationError.invalidAccountAssets("duplicate_asset_scope")
            }
        }
    }

    private func irohaDefinitionsByCanonicalId(
        _ definitions: [IrohaAssetDefinitionListItem]
    ) throws -> [String: IrohaAssetDefinitionListItem] {
        try definitions.reduce(into: [:]) { result, definition in
            let id: String
            do {
                id = try IrohaToriiRoutes.normalizeAssetDefinitionId(definition.id)
            } catch {
                throw IrohaAssetConfigurationError.nonCanonicalDefinition(definition.id)
            }
            guard result[id] == nil else {
                throw IrohaAssetConfigurationError.duplicateDefinition(id)
            }
            result[id] = definition
        }
    }

    private func irohaProfilePrecision(
        for asset: AssetModel,
        canonicalAssetId: String,
        network: UniversalWalletRegistry.IrohaNetwork
    ) throws -> UInt16 {
        guard let nativeAsset = network.nativeAsset, nativeAsset.id == canonicalAssetId else {
            return asset.precision
        }
        guard asset.symbol == nativeAsset.symbol, Int(asset.precision) == nativeAsset.decimals else {
            throw IrohaAssetConfigurationError.nativeProfileMismatch(
                assetId: canonicalAssetId,
                symbol: asset.symbol,
                precision: asset.precision
            )
        }

        return UInt16(nativeAsset.decimals)
    }

    private func irohaPrecision(
        expectedPrecision: UInt16,
        definition: IrohaAssetDefinitionListItem
    ) throws -> UInt16 {
        guard let scale = definition.spec?.scale else {
            throw IrohaAssetConfigurationError.missingScale(definition.id)
        }
        guard scale >= 0,
              scale <= Int(UInt16.max),
              UInt16(scale) == expectedPrecision else {
            throw IrohaAssetConfigurationError.precisionMismatch(
                assetId: definition.id,
                wallet: expectedPrecision,
                torii: scale
            )
        }

        return UInt16(scale)
    }

    private func irohaPlanks(from quantity: String, precision: UInt16) -> BigUInt? {
        let normalized = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$"#
        guard normalized == quantity,
              precision <= 28,
              normalized.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else {
            return nil
        }

        let integerPart = String(parts[0])
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        let digits = integerPart + fractionPart
        guard fractionPart.count <= Int(precision),
              digits.count <= 154,
              let mantissa = BigUInt(digits),
              mantissa <= maxIrohaNumeric else {
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
