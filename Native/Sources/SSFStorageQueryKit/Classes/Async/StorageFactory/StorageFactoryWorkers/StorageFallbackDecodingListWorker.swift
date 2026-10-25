import Foundation
import SSFModels
import SSFRuntimeCodingService

final class StorageFallbackDecodingListWorker<T: Decodable>: StorageDecodable,
    StorageModifierHandling
{
    private let dataList: [Data?]
    private let codingFactory: RuntimeCoderFactoryProtocol
    private let path: any StorageCodingPathProtocol

    init(
        codingFactory: RuntimeCoderFactoryProtocol,
        path: any StorageCodingPathProtocol,
        dataList: [Data?]
    ) {
        self.codingFactory = codingFactory
        self.path = path
        self.dataList = dataList
    }

    func performDecoding() throws -> [T?] {
        let items: [T?] = try dataList.map { data in
            if let data = data {
                return try decode(data: data, path: path, codingFactory: codingFactory)
                    .map(to: T.self)
            } else {
                return try handleModifier(at: path, codingFactory: codingFactory)?.map(to: T.self)
            }
        }
        return items
    }
}
