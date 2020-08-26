import Foundation
import FearlessUtils

protocol ManagedAccountViewModelFactoryProtocol {
    func createViewModelFromItem(_ item: ManagedAccountItem, selected: Bool) -> ManagedAccountViewModelItem
}

final class ManagedAccountViewModelFactory: ManagedAccountViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createViewModelFromItem(_ item: ManagedAccountItem, selected: Bool) -> ManagedAccountViewModelItem {
        let icon = try? iconGenerator.generateFromAddress(item.address)

        return ManagedAccountViewModelItem(name: item.username,
                                           address: item.address,
                                           icon: icon,
                                           isSelected: selected)
    }
}
