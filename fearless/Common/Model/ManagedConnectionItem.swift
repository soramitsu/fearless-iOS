import Foundation
import IrohaCrypto

struct ManagedConnectionItem: Equatable {
    let title: String
    let url: URL
    let type: SNAddressType
    let order: Int16
}

extension ManagedConnectionItem {
    func replacingOrder(_ newOrder: Int16) -> ManagedConnectionItem {
        ManagedConnectionItem(title: title,
                              url: url,
                              type: type,
                              order: newOrder)
    }
}
