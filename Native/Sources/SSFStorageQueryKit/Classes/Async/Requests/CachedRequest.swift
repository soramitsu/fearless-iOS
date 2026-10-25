import Foundation
import SSFModels

public protocol CacheableKeyedRequest {
    var workerType: StorageRequestWorkerType { get }
    var storagePath: any StorageCodingPathProtocol { get }
    var keyType: MapKeyType { get }
}
