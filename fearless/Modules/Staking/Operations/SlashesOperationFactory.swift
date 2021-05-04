import Foundation
import RobinHood
import IrohaCrypto

protocol SlashesOperationFactoryProtocol {
    func createSlashingSpansOperationForStash(
        _ stashAddress: AccountAddress,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
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
        runtimeService: RuntimeCodingServiceProtocol
    )
        -> CompoundOperationWrapper<SlashingSpans?> {
        let runtimeFetchOperation = runtimeService.fetchCoderFactoryOperation()

        let keyParams: () throws -> [AccountId] = {
            let accountId: AccountId = try SS58AddressFactory().accountId(from: stashAddress)
            return [accountId]
        }

        let fetchOperation: CompoundOperationWrapper<[StorageResponse<SlashingSpans>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: {
                    try runtimeFetchOperation.extractNoCancellableResultData()
                }, storagePath: .slashingSpans
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
