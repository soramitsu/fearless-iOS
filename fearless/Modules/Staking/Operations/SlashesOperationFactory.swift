import Foundation
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

protocol SlashesOperationFactoryProtocol {
    func createSlashingSpansOperationForStash(
        _ stashAddress: AccountAddress,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainAsset: ChainAsset
    )
        -> CompoundOperationWrapper<SlashingSpans?>
}

final class SlashesOperationFactory {
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
    }
}

extension SlashesOperationFactory: SlashesOperationFactoryProtocol {
    func createSlashingSpansOperationForStash(
        _ stashAddress: AccountAddress,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<SlashingSpans?> {
        guard let stakingSettings = chainAsset.chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(StakingServiceFactoryError.stakingUnavailable)
        }

        let runtimeFetchOperation = runtimeService.fetchCoderFactoryOperation()

        let keyParams: () throws -> [AccountId] = {
            let accountId: AccountId = try AddressFactory.accountId(from: stashAddress, chain: chainAsset.chain)
            return [accountId]
        }

        let fetchOperation: CompoundOperationWrapper<[StorageResponse<SlashingSpans>]> = stakingSettings.queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: { try runtimeFetchOperation.extractNoCancellableResultData() },
            storagePath: .slashingSpans,
            using: storageRequestFactory
        )

        fetchOperation.allOperations.forEach { $0.addDependency(runtimeFetchOperation) }

        let mapOperation = ClosureOperation<SlashingSpans?> {
            try fetchOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(fetchOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [runtimeFetchOperation] + fetchOperation.allOperations
        )
    }
}
