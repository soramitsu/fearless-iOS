import Foundation
import RobinHood

protocol ParachainStakingLocalSubscriptionFactoryProtocol {
    func getCandidatePool(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedParachainStakingCandidate>
}

final class ParachainStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory, ParachainStakingLocalSubscriptionFactoryProtocol {
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
}
