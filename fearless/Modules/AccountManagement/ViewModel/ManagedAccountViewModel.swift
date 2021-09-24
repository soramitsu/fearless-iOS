import UIKit
import FearlessUtils

struct ManagedAccountViewModelItem: Equatable {
    let identifier: String
    let name: String
    let address: String
    let icon: DrawableIcon?
    let isSelected: Bool

    static func == (lhs: ManagedAccountViewModelItem, rhs: ManagedAccountViewModelItem) -> Bool {
        lhs.identifier == rhs.identifier &&
            lhs.address == rhs.address &&
            lhs.name == rhs.name &&
            lhs.isSelected == rhs.isSelected
    }
}
