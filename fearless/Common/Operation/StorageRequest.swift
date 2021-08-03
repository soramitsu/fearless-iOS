import Foundation

struct StorageRequestParams {
    let path: StorageCodingPath
    let shouldFallback: Bool

    init(path: StorageCodingPath, shouldFallback: Bool = true) {
        self.path = path
        self.shouldFallback = shouldFallback
    }
}
