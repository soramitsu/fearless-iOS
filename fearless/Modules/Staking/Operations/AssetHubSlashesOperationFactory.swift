import Foundation
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
import BigInt

struct AssetHubValidatorSlash: Decodable {
    let fraction: UInt32
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        fraction = try values.decode(StringScaleMapper<UInt32>.self).value
        amount = try values.decode(StringScaleMapper<BigUInt>.self).value
        guard values.isAtEnd, fraction <= 1_000_000_000 else { throw EraValidatorServiceError.unexpectedInfo }
    }
}

struct AssetHubSlashesOperationFactory {
    let engine: JSONRPCEngine
    let runtime: RuntimeCodingServiceProtocol
    var storage: AsyncStorageRequestFactory = AsyncStorageRequestDefault()

    func validatorSlashes(ids: [AccountId], submittedIn era: EraIndex) -> CompoundOperationWrapper<[AccountId: Bool]> {
        let operation = AwaitOperation<[AccountId: Bool]> {
            let coder = try await runtime.fetchCoderFactory()
            let hash: String = try await JSONRPCListWorker(engine: engine, method: RPCMethod.getFinalizedBlockHash, parameters: []).performCall()
            let scanner = AssetHubPagedStorage(engine: engine, runtime: coder, block: try Data(hexStringSSF: hash), storage: storage)
            var result = Dictionary(uniqueKeysWithValues: Set(ids).map { ($0, false) })
            try await scanner.forEachPage(path: .validatorSlashInEra) { (responses: [StorageResponse<AssetHubValidatorSlash>]) in
                for response in responses {
                    let key: ErasStakersOverviewKey = try scanner.decodeKey(response.key, path: .validatorSlashInEra, type: .erasStakersOverviewKey)
                    guard let value = response.value else { throw AssetHubPagedStorage.Failure.invalidPage }
                    if key.era > era, result[key.accountId] != nil, value.fraction > 0 || value.amount > 0 {
                        result[key.accountId] = true
                    }
                }
            }
            return result
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func unapplied() -> UnappliedSlashesWrapper {
        let operation = AwaitOperation<[StorageResponse<[UnappliedSlash]>]> {
            let coder = try await runtime.fetchCoderFactory()
            let hash: String = try await JSONRPCListWorker(engine: engine, method: RPCMethod.getFinalizedBlockHash, parameters: []).performCall()
            let scanner = AssetHubPagedStorage(engine: engine, runtime: coder, block: try Data(hexStringSSF: hash), storage: storage)
            var result: [StorageResponse<[UnappliedSlash]>] = []
            try await scanner.forEachPage(path: .unappliedSlashes) { (responses: [StorageResponse<UnappliedSlash>]) in
                for response in responses {
                    guard let value = response.value else { throw AssetHubPagedStorage.Failure.invalidPage }
                    result.append(StorageResponse(key: response.key, data: response.data, value: [value]))
                }
            }
            return result
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
