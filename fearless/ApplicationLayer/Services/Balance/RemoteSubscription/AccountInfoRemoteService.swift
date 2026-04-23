import Foundation
import SSFStorageQueryKit
import SSFChainRegistry
import SSFNetwork
import SSFModels
import SSFUtils
import RobinHood

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

final class AccountInfoRemoteServiceDefault: AccountInfoRemoteService {
    private enum ChainKind {
        case substrate
        case ethereum
        case ton
    }

    private let ethereumRemoteBalanceFetching: EthereumRemoteBalanceFetching
    private let tonRemoteBalanceFetching: AccountInfoRemoteService?
    private let storagePerformer: SSFStorageQueryKit.StorageRequestPerformer

    init(
        ethereumRemoteBalanceFetching: EthereumRemoteBalanceFetching,
        tonRemoteBalanceFetching: AccountInfoRemoteService?,
        storagePerformer: SSFStorageQueryKit.StorageRequestPerformer
    ) {
        self.ethereumRemoteBalanceFetching = ethereumRemoteBalanceFetching
        self.tonRemoteBalanceFetching = tonRemoteBalanceFetching
        self.storagePerformer = storagePerformer
    }

    // MARK: - AccountInfoStorageService

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            throw ConvenienceError(error: "Missing AccountId for chain: \(chain.name)")
        }

        switch chainKind(for: chain) {
        case .ethereum:
            return try await fetchEthereum(for: chain, wallet: wallet)
        case .ton:
            guard let tonRemoteBalanceFetching else {
                throw ConvenienceError(error: "TON remote fetching unavailable")
            }
            return try await tonRemoteBalanceFetching.fetchAccountInfos(for: chain, wallet: wallet)
        case .substrate:
            return try await fetchSubstrate(for: chain, accountId: accountId)
        }
    }

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo? {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            throw ConvenienceError(error: "Missing account id for \(chainAsset.debugName)")
        }
        switch chainKind(for: chainAsset.chain) {
        case .ethereum:
            let response = try await ethereumRemoteBalanceFetching.fetch(for: chainAsset, accountId: accountId)
            return response.1
        case .ton:
            guard let tonRemoteBalanceFetching else {
                throw ConvenienceError(error: "TON remote fetching unavailable")
            }
            return try await tonRemoteBalanceFetching.fetchAccountInfo(for: chainAsset, wallet: wallet)
        case .substrate:
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

        if chain.chainBaseType == .ethereum {
            return .ethereum
        }

        return .substrate
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
        if chainAsset.chain.isEquilibrium {
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
}
