import Foundation
import RobinHood

struct ChainStorageItem: StorageWrapper {
    enum CodingKeys: String, CodingKey {
        case identifier
        case data
    }

    let identifier: String
    let data: Data
}
