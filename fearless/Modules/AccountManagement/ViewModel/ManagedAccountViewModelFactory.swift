import Foundation
import SSFUtils

protocol ManagedAccountViewModelFactoryProtocol {
    func createViewModelFromItem(_ item: ManagedMetaAccountModel) -> ManagedAccountViewModelItem
}

final class ManagedAccountViewModelFactory: ManagedAccountViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createViewModelFromItem(_ item: ManagedMetaAccountModel) -> ManagedAccountViewModelItem {
        let address = (try? item.info.substrateAccountId.toAddress(using: .substrate(42))) ?? ""
        let icon = try? iconGenerator.generateFromAddress(address)

        return ManagedAccountViewModelItem(
            identifier: item.identifier,
            name: item.info.name,
            totalBalance: item.balance,
            icon: icon,
            isSelected: item.isSelected
        )
    }
}
