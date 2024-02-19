import Foundation
import RobinHood

protocol StorageNetworkWorker {
    func fetch<T: Decodable>(using operation: CompoundOperationWrapper<[StorageResponse<T>]>) async throws -> [StorageResponse<T>]
}
