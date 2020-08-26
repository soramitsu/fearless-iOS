import UIKit
import FearlessUtils

struct ManagedAccountViewModelItem: Equatable {
    let name: String
    let address: String
    let icon: DrawableIcon?
    let isSelected: Bool

    static func == (lhs: ManagedAccountViewModelItem, rhs: ManagedAccountViewModelItem) -> Bool {
        lhs.name == rhs.name && lhs.address == rhs.address && lhs.isSelected == rhs.isSelected
    }
}

struct ManagedAccountViewModelSection: Equatable {
    let title: String
    let icon: UIImage?
    let items: [ManagedAccountViewModelItem]
}
