import Foundation
import RobinHood

protocol ParachainStakingLocalSubscriptionFactoryProtocol {
    func getCandidatePool(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedParachainStakingCandidate>

    func getDelegatorState(
        chainAsset: ChainAsset,
        accountId: AccountId
    ) throws
        -> AnyDataProvider<DecodedParachainDelegatorState>

    func getDelegationScheduledRequests(
        chainAsset: ChainAsset,
        accountId: AccountId
    ) throws
        -> AnyDataProvider<DecodedParachainScheduledRequests>
}

final class ParachainStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory, ParachainStakingLocalSubscriptionFactoryProtocol {
    func getDelegationScheduledRequests(
        chainAsset: ChainAsset,
        accountId: AccountId
    ) throws -> AnyDataProvider<DecodedParachainScheduledRequests> {
        let codingPath = StorageCodingPath.delegationScheduledRequests
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainAsset.chain.chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getCandidatePool(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedParachainStakingCandidate> {
        let codingPath = StorageCodingPath.candidatePool
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getDelegatorState(
        chainAsset: ChainAsset,
        accountId: AccountId
    ) throws -> AnyDataProvider<DecodedParachainDelegatorState> {
        let codingPath = StorageCodingPath.delegatorState
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainAsset.chain.chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }
}
