import Foundation
import RobinHood

protocol CrowdloanLocalSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber>
}

final class CrowdloanLocalSubscriptionFactory: LocalSubscriptionFactory, CrowdloanLocalSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber> {
        let codingPath = StorageCodingPath.blockNumber
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }
}
