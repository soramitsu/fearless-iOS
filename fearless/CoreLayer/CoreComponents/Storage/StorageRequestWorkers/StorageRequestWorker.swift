import Foundation
import SSFUtils
import SSFModels

enum StorageRequestWorkerError: Error {
    case invalidParameters
}

protocol StorageRequestWorker: AnyObject {
    func perform<T: Decodable>(
        params: StorageRequestWorkerType,
        storagePath: StorageCodingPath
    ) async throws -> [StorageResponse<T>]
}
