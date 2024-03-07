import Foundation
import SSFModels

protocol PrefixRequest {
    var storagePath: StorageCodingPath { get }
    var keyType: MapKeyType { get }
}
