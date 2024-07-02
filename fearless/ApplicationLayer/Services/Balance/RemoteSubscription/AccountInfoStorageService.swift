import Foundation
import SSFStorageQueryKit
import SSFChainRegistry
import SSFNetwork
import SSFModels
import SSFUtils
import RobinHood

final class AccountInfoRemoteServiceDefault: AccountInfoRemoteService {
    private let runtimeItemRepository: AsyncAnyRepository<RuntimeMetadataItem>
    private let ethereumRemoteBalanceFetching: EthereumRemoteBalanceFetching
    private let chainRegistry: SSFChainRegistry.ChainRegistryProtocol

    init(
        runtimeItemRepository: AsyncAnyRepository<RuntimeMetadataItem>,
        ethereumRemoteBalanceFetching: EthereumRemoteBalanceFetching,
        chainRegistry: SSFChainRegistry.ChainRegistryProtocol
    ) {
        self.runtimeItemRepository = runtimeItemRepository
        self.ethereumRemoteBalanceFetching = ethereumRemoteBalanceFetching
        self.chainRegistry = chainRegistry
    }

    // MARK: - AccountInfoStorageService

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            return emptyAccountInfos(for: chain)
        }

        if chain.isEthereum {
            let accountInfos = try await fetchEthereum(for: chain, wallet: wallet)
            return accountInfos
        } else {
            let accountInfos = try await fetchSubstrate(for: chain, accountId: accountId)
            return accountInfos
        }
    }

    // MARK: - Private substrate methods

    private func fetchSubstrate(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetId: AccountInfo?] {
        guard let performer = try await createStoragePerformer(for: chain) else {
            Logger.shared.error("Performer not created for chain: \(chain.name)")
            return emptyAccountInfos(for: chain)
        }
        let requests = chain.chainAssets.map { createSubstrateRequest(for: $0, accountId: accountId) }
        let result = try await performer.perform(requests)
        let map = try createSubstrateMap(from: result, chain: chain)

        return map
    }

    private func emptyAccountInfos(for chain: ChainModel) -> [ChainAssetId: AccountInfo?] {
        Dictionary(uniqueKeysWithValues: chain.chainAssets.map { ($0.chainAssetId, nil) })
    }

//    private func createRequests(
//        for chain: ChainModel,
//        accountId: AccountId
//    ) -> [any MixStorageRequest] {
//        if chain.isEquilibrium {
//            let request = EquilibriumAccountInfotorageRequest(
//                parametersType: .encodable(param: accountId),
//                storagePath: StorageCodingPath.account,
//                requestId: chain.chainId
//            )
//            return [request]
//        } else {
//            let requests = chain.chainAssets.map { createSubstrateRequest(for: $0, accountId: accountId) }
//            return requests
//        }
//    }

    private func createSubstrateMap(
        from result: [MixStorageResponse],
        chain: ChainModel
    ) throws -> [ChainAssetId: AccountInfo?] {
        try result.reduce([ChainAssetId: AccountInfo?]()) { part, response in
            var partial = part
            let id = ChainAssetId(id: response.request.requestId)

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

    private func createStoragePerformer(for chain: ChainModel) async throws -> SSFStorageQueryKit.StorageRequestPerformer? {
        guard let runtimeItem = try await runtimeItemRepository.fetch(by: chain.chainId) else {
            return nil
        }
        let performer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: chainRegistry,
            chain: chain,
            runtimeItem: runtimeItem
        )
        return performer
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

// extension AccountInfo: MixStorageResponseValue {
//    static func getValue(from json: SSFUtils.JSON) throws -> AccountInfo {
//        try json.map(to: AccountInfo.self)
//    }
// }
//
// extension OrmlAccountInfo: MixStorageResponseValue {
//    static func getValue(from json: JSON) throws -> OrmlAccountInfo {
//        try json.map(to: OrmlAccountInfo.self)
//    }
// }
//
// extension EquilibriumAccountInfo: MixStorageResponseValue {
//    static func getValue(from json: JSON) throws -> EquilibriumAccountInfo {
//        try json.map(to: EquilibriumAccountInfo.self)
//    }
// }
//
// extension AssetAccount: MixStorageResponseValue {
//    static func getValue(from json: JSON) throws -> AssetAccount {
//        try json.map(to: AssetAccount.self)
//    }
// }
