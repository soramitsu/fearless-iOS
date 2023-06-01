import UIKit
import SSFUtils

struct ManagedAccountViewModelItem: Equatable {
    let identifier: String
    let name: String
    let totalBalance: String?
    let icon: DrawableIcon?
    let isSelected: Bool

    static func == (lhs: ManagedAccountViewModelItem, rhs: ManagedAccountViewModelItem) -> Bool {
        lhs.identifier == rhs.identifier &&
            lhs.totalBalance == rhs.totalBalance &&
            lhs.name == rhs.name &&
            lhs.isSelected == rhs.isSelected
    }
}
