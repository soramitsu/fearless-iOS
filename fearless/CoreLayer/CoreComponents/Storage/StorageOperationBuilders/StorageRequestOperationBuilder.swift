import Foundation
import SSFUtils
import RobinHood

enum NMapStorageRequestOperationBuilderError: Error {
    case invalidParameters
}

protocol StorageRequestOperationBuilder: AnyObject {
    func createStorageRequestOperation<T: Decodable>(request: some StorageRequest) -> CompoundOperationWrapper<[StorageResponse<T>]>
}
