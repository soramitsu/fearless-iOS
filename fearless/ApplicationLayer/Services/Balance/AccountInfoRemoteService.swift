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

    func fetchAccountInfos(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?]
}

final class AccountInfoRemoteServiceDefault: AccountInfoRemoteService {
    private let ethereumRemoteBalanceFetching: AccountInfoRemoteService
    private let tonRemoteBalanceFetching: AccountInfoRemoteService
    private let substrateRemoteBalanceFetching: AccountInfoRemoteService

    init(
        ethereumRemoteBalanceFetching: AccountInfoRemoteService,
        tonRemoteBalanceFetching: AccountInfoRemoteService,
        substrateRemoteBalanceFetching: AccountInfoRemoteService
    ) {
        self.ethereumRemoteBalanceFetching = ethereumRemoteBalanceFetching
        self.tonRemoteBalanceFetching = tonRemoteBalanceFetching
        self.substrateRemoteBalanceFetching = substrateRemoteBalanceFetching
    }

    // MARK: - AccountInfoStorageService

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        let fetcher = getFetcher(for: chain.ecosystem)
        let accountInfos = try await fetcher.fetchAccountInfos(for: chain, wallet: wallet)
        return accountInfos
    }

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo? {
        let fetcher = getFetcher(for: chainAsset.chain.ecosystem)
        let accountInfos = try await fetcher.fetchAccountInfo(for: chainAsset, wallet: wallet)
        return accountInfos
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
                    let fetcher = self.getFetcher(for: chain.ecosystem)
                    let result = try await fetcher.fetchAccountInfos(for: chainAssets, wallet: wallet)
                    return result
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

    private func getFetcher(for ecosystem: Ecosystem) -> AccountInfoRemoteService {
        switch ecosystem {
        case .substrate, .ethereumBased:
            return substrateRemoteBalanceFetching
        case .ethereum:
            return ethereumRemoteBalanceFetching
        case .ton:
            return tonRemoteBalanceFetching
        }
    }
}
