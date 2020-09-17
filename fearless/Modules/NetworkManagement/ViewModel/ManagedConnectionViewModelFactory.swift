import Foundation
import IrohaCrypto

protocol ManagedConnectionViewModelFactoryProtocol {
    func createViewModelFromManagedItem(_ item: ManagedConnectionItem,
                                        selected: Bool) -> ManagedConnectionViewModel
    func createViewModelFromConnectionItem(_ item: ConnectionItem,
                                           selected: Bool) -> ManagedConnectionViewModel
}

final class ManagedConnectionViewModelFactory: ManagedConnectionViewModelFactoryProtocol {
    func createViewModelFromManagedItem(_ item: ManagedConnectionItem,
                                        selected: Bool) -> ManagedConnectionViewModel {
        ManagedConnectionViewModel(identifier: item.identifier,
                                   name: item.title,
                                   type: item.type,
                                   isSelected: selected)
    }

    func createViewModelFromConnectionItem(_ item: ConnectionItem,
                                           selected: Bool) -> ManagedConnectionViewModel {
        ManagedConnectionViewModel(identifier: item.identifier,
                                   name: item.title,
                                   type: item.type,
                                   isSelected: selected)
    }
}
