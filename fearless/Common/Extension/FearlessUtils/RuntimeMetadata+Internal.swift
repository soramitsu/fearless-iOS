import Foundation
import FearlessUtils

extension RuntimeMetadata {
    func getStorageMetadata(for codingPath: StorageCodingPath) -> StorageEntryMetadata? {
        getStorageMetadata(in: codingPath.moduleName, storageName: codingPath.itemName)
    }
}
