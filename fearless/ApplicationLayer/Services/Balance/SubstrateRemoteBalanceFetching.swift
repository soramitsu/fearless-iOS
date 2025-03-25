import Foundation
import SSFModels
import SSFStorageQueryKit

actor SubstrateRemoteBalanceFetchingImpl: AccountInfoRemoteService {
    private let storagePerformer: StorageRequestPerformer

    init(storagePerformer: StorageRequestPerformer) {
        self.storagePerformer = storagePerformer
    }

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            throw ConvenienceError(error: "Missing AccountId for chain: \(chain.name)")
        }
        let accountInfos = try await fetchSubstrate(for: chain, accountId: accountId)
        return accountInfos
    }

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo? {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            throw ConvenienceError(error: "Missing account id for \(chainAsset.debugName)")
        }
        let request = createSubstrateRequest(for: chainAsset, accountId: accountId)
        let response = try await storagePerformer.perform([request], chain: chainAsset.chain)
        let map = try await createSubstrateMap(from: response, chain: chainAsset.chain)
        let accountInfo = map[chainAsset.chainAssetId] ?? nil
        return accountInfo
    }

    func fetchAccountInfos(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        let dict = Dictionary(grouping: chainAssets, by: { $0.chain })
        let balances = try await withThrowingTaskGroup(
            of: [ChainAssetKey: AccountInfo?].self,
            returning: [ChainAssetKey: AccountInfo?].self
        ) { [weak self] group in
            guard let self else { return [:] }

            dict.forEach { chain, chainAssets in
                group.addTask {
                    guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
                        throw ConvenienceError(error: "Missing account id for \(chain.name)")
                    }
                    let requests = await chainAssets.asyncMap { await self.createSubstrateRequest(for: $0, accountId: accountId) }
                    let result = try await self.storagePerformer.perform(requests, chain: chain)
                    let map = try await self.createSubstrateMap(from: result, chain: chain, accountId: accountId)
                    return map
                }
            }

            var result: [ChainAssetKey: AccountInfo?] = [:]
            for try await balance in group {
                result = result.merging(balance, uniquingKeysWith: { current, _ in current })
            }
            return result
        }

        return balances
    }

    // MARK: - Private methods

    private func fetchSubstrate(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetId: AccountInfo?] {
        let requests = chain.chainAssets.map { createSubstrateRequest(for: $0, accountId: accountId) }
        let result = try await storagePerformer.perform(requests, chain: chain)
        let map = try await createSubstrateMap(from: result, chain: chain)
        return map
    }

    private func createSubstrateMap(
        from result: [MixStorageResponse],
        chain: ChainModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        try result.reduce([ChainAssetId: AccountInfo?]()) { part, response in
            var partial = part
            let id = ChainAssetId(id: response.request.requestId)

            let accountInfo = try mapAccountInfo(response: response, chain: chain)
            partial[id] = accountInfo

            return partial
        }
    }

    private func createSubstrateMap(
        from result: [MixStorageResponse],
        chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        try result.reduce([ChainAssetKey: AccountInfo?]()) { part, response in
            var partial = part
            let id = ChainAssetId(id: response.request.requestId)
            guard let chainAsset = chain.chainAssets.first(where: { $0.chainAssetId == id }) else {
                return part
            }
            let key = chainAsset.uniqueKey(accountId: accountId)

            let accountInfo = try mapAccountInfo(response: response, chain: chain)
            partial[key] = accountInfo

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
            let chainAssetId = ChainAssetId(id: response.request.requestId)
            guard
                let chainAsset = chain.chainAssets.first(where: { $0.chainAssetId == chainAssetId }),
                let currencyId = chainAsset.asset.currencyId
            else {
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
        if chainAsset.chain.knownChainEquivalent == .genshiro {
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
                let params: [[any NMapKeyParamProtocol]] = [
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
            let params: [[any NMapKeyParamProtocol]] = [
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
            let params: [[any NMapKeyParamProtocol]] = [
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
}
