import Foundation
import SSFRuntimeCodingService
import SSFUtils

final class ChildStorageResponseDecodingWorker<T: Decodable> {
    private let factory: RuntimeCoderFactoryProtocol
    private let mapper: DynamicScaleDecodable
    private let queryResponse: String?
    private let storageKey: Data
    private let childKey: Data

    init(
        factory: RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable,
        queryResponse: String?,
        storageKey: Data,
        childKey: Data
    ) {
        self.factory = factory
        self.mapper = mapper
        self.queryResponse = queryResponse
        self.storageKey = storageKey
        self.childKey = childKey
    }

    func performDecode() throws -> ChildStorageResponse<T> {
        if let hexData = queryResponse {
            let data = try Data(hexStringSSF: hexData)
            let decoder = try factory.createDecoder(from: data)
            let json = try mapper.accept(decoder: decoder)
            let value = try json.map(to: T.self)

            return ChildStorageResponse(storageKey: storageKey, childKey: childKey, data: data, value: value)
        } else {
            return ChildStorageResponse(storageKey: storageKey, childKey: childKey, data: nil, value: nil)
        }
    }
}
