import Foundation
import IrohaCrypto

struct ManagedConnectionViewModel: Equatable {
    let identifier: String
    let name: String
    let type: SNAddressType
    let isSelected: Bool
}
