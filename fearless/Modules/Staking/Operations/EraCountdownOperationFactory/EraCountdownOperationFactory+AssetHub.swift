import Foundation
import RobinHood
import SSFUtils
import SSFRuntimeCodingService

struct BondedEra: Decodable, Equatable {
    let era: EraIndex
    let session: SessionIndex

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        era = try container.decode(StringScaleMapper<EraIndex>.self).value
        session = try container.decode(StringScaleMapper<SessionIndex>.self).value
        guard container.isAtEnd else { throw EraCountdownOperationFactoryError.noData }
    }
}

extension EraCountdownOperationFactory {
    func createBondedEraStartSessionIndex(
        dependingOn activeEra: BaseOperation<[StorageResponse<ActiveEraInfo>]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        engine: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> {
        let wrapper: CompoundOperationWrapper<[StorageResponse<[BondedEra]>]> = storageRequestFactory.queryItems(
            engine: engine,
            keys: { [try StorageKeyFactory().key(from: .bondedEras)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: .bondedEras
        )
        let operation = ClosureOperation<[StorageResponse<StringScaleMapper<SessionIndex>>]> {
            guard let era = try activeEra.extractNoCancellableResultData().first?.value?.index,
                  let response = try wrapper.targetOperation.extractNoCancellableResultData().first,
                  let matching = response.value?.filter({ $0.era == era }), matching.count == 1,
                  let session = matching.first?.session else {
                throw EraCountdownOperationFactoryError.noData
            }
            return [StorageResponse(key: response.key, data: response.data, value: StringScaleMapper(value: session))]
        }
        operation.addDependency(activeEra)
        operation.addDependency(wrapper.targetOperation)
        return CompoundOperationWrapper(targetOperation: operation, dependencies: wrapper.allOperations)
    }
}
