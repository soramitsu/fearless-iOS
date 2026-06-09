import Foundation
import SSFModels

protocol AccountInfoFetchingProtocol {
    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    )

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    )

    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> (ChainAsset, AccountInfo?)

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?]

    func fetchByUniqKey(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?]
}

final class CompositeAccountInfoFetching: AccountInfoFetchingProtocol {
    private let substrateFetching: AccountInfoFetchingProtocol
    private let ethereumFetching: AccountInfoFetchingProtocol

    init(
        substrateFetching: AccountInfoFetchingProtocol,
        ethereumFetching: AccountInfoFetchingProtocol
    ) {
        self.substrateFetching = substrateFetching
        self.ethereumFetching = ethereumFetching
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        Task {
            do {
                let result = try await fetch(for: chainAsset, accountId: accountId)
                completionBlock(result.0, result.1)
            } catch {
                completionBlock(chainAsset, nil)
            }
        }
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        Task {
            do {
                let result = try await fetch(for: chainAssets, wallet: wallet)
                completionBlock(result)
            } catch {
                completionBlock([:])
            }
        }
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> (ChainAsset, AccountInfo?) {
        let fetcher = chainAsset.chain.isEthereum ? ethereumFetching : substrateFetching
        return try await fetcher.fetch(for: chainAsset, accountId: accountId)
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        let splitChainAssets = split(chainAssets)

        guard splitChainAssets.substrate.isNotEmpty else {
            return try await ethereumFetching.fetch(for: splitChainAssets.ethereum, wallet: wallet)
        }

        guard splitChainAssets.ethereum.isNotEmpty else {
            return try await substrateFetching.fetch(for: splitChainAssets.substrate, wallet: wallet)
        }

        async let substrateResult: [ChainAsset: AccountInfo?] = substrateFetching.fetch(
            for: splitChainAssets.substrate,
            wallet: wallet
        )
        async let ethereumResult: [ChainAsset: AccountInfo?] = ethereumFetching.fetch(
            for: splitChainAssets.ethereum,
            wallet: wallet
        )

        var result = try await substrateResult
        merge(try await ethereumResult, into: &result)
        return result
    }

    func fetchByUniqKey(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        let splitChainAssets = split(chainAssets)

        guard splitChainAssets.substrate.isNotEmpty else {
            return try await ethereumFetching.fetchByUniqKey(for: splitChainAssets.ethereum, wallet: wallet)
        }

        guard splitChainAssets.ethereum.isNotEmpty else {
            return try await substrateFetching.fetchByUniqKey(for: splitChainAssets.substrate, wallet: wallet)
        }

        async let substrateResult: [ChainAssetKey: AccountInfo?] = substrateFetching.fetchByUniqKey(
            for: splitChainAssets.substrate,
            wallet: wallet
        )
        async let ethereumResult: [ChainAssetKey: AccountInfo?] = ethereumFetching.fetchByUniqKey(
            for: splitChainAssets.ethereum,
            wallet: wallet
        )

        var result = try await substrateResult
        merge(try await ethereumResult, into: &result)
        return result
    }
}

private extension CompositeAccountInfoFetching {
    func split(_ chainAssets: [ChainAsset]) -> (substrate: [ChainAsset], ethereum: [ChainAsset]) {
        chainAssets.reduce(into: (substrate: [ChainAsset](), ethereum: [ChainAsset]())) { result, chainAsset in
            if chainAsset.chain.isEthereum {
                result.ethereum.append(chainAsset)
            } else {
                result.substrate.append(chainAsset)
            }
        }
    }

    func merge<Key>(
        _ source: [Key: AccountInfo?],
        into target: inout [Key: AccountInfo?]
    ) {
        source.forEach { key, value in
            target.updateValue(value, forKey: key)
        }
    }
}
