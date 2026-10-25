import Foundation
import SSFModels
import SSFUtils

enum StorageRequestWorkerError: Error {
    case invalidParameters(moduleName: String, itemName: String)
}

protocol StorageRequestWorker: AnyObject {
    func perform<T: Decodable>(
        params: StorageRequestWorkerType,
        storagePath: any StorageCodingPathProtocol
    ) async throws -> [StorageResponse<T>]
}
