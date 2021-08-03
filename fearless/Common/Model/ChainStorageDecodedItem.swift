import Foundation
import RobinHood

struct ChainStorageDecodedItem<T: Equatable & Decodable>: Equatable {
    let identifier: String
    let item: T?
}

extension ChainStorageDecodedItem: Identifiable {}
