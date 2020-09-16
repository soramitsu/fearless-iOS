import Foundation
import IrohaCrypto

struct ManagedConnectionItem: Equatable {
    let title: String
    let url: URL
    let type: SNAddressType
    let order: Int16
}
