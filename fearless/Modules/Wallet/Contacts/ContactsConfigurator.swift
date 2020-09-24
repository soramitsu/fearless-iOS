import Foundation
import IrohaCrypto
import CommonWallet

final class ContactsConfigurator {
    private var localSearchEngine: ContactsLocalSearchEngine

    weak var commandFactory: WalletCommandFactoryProtocol? {
        get {
            localSearchEngine.commandFactory
        }

        set {
            localSearchEngine.commandFactory = newValue
        }
    }

    init(networkType: SNAddressType) {
        localSearchEngine = ContactsLocalSearchEngine(networkType: networkType)
    }

    func configure(builder: ContactsModuleBuilderProtocol) {
        let actionFactory = ContactsActionFactory()

        builder
            .with(localSearchEngine: localSearchEngine)
            .with(scanPosition: .barButton)
            .with(actionFactoryWrapper: actionFactory)
            .with(canFindItself: false)
            .with(searchEmptyStateDataSource: WalletEmptyStateDataSource.search)
            .with(contactsEmptyStateDataSource: WalletEmptyStateDataSource.contacts)
            .with(viewStyle: ContactsViewStyle.fearless)
            .with(contactCellStyle: ContactCellStyle.fearless)
            .with(sectionHeaderStyle: WalletTextStyle(font: UIFont.capsTitle, color: R.color.colorLightGray()!))
    }
}
