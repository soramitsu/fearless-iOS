import Foundation
import CommonWallet

final class ContactsListViewModelFactory: ContactsListViewModelFactoryProtocol {
    private var itemViewModelFactory = ContactsViewModelFactory()

    func createContactViewModelListFromItems(_ items: [SearchData],
                                             parameters: ContactModuleParameters,
                                             locale: Locale,
                                             delegate: ContactViewModelDelegate?,
                                             commandFactory: WalletCommandFactoryProtocol)
    -> [ContactSectionViewModelProtocol] {
        let (localItems, remoteItems) = items.reduce(([SearchData](), [SearchData]())) { (result, item) in
            let context = ContactContext(context: item.context ?? [:])

            switch context.destination {
            case .local:
                return (result.0 + [item], result.1)
            case .remote:
                return (result.0, result.1 + [item])
            }
        }

        var sections = [ContactSectionViewModelProtocol]()

        if !localItems.isEmpty {
            let viewModels = createSearchViewModelListFromItems(localItems,
                                                                parameters: parameters,
                                                                locale: locale,
                                                                delegate: delegate,
                                                                commandFactory: commandFactory)

            let sectionTitle = R.string.localizable
                .walletSearchAccounts(preferredLanguages: locale.rLanguages)
            let section = ContactSectionViewModel(title: sectionTitle,
                                                  items: viewModels)
            sections.append(section)
        }

        if !remoteItems.isEmpty {
            let viewModels = createSearchViewModelListFromItems(remoteItems,
                                                                parameters: parameters,
                                                                locale: locale,
                                                                delegate: delegate,
                                                                commandFactory: commandFactory)
            let sectionTitle = R.string.localizable
                .walletSearchContacts(preferredLanguages: locale.rLanguages)
            let section = ContactSectionViewModel(title: sectionTitle,
                                                  items: viewModels)
            sections.append(section)
        }

        return sections
    }

    func createSearchViewModelListFromItems(_ items: [SearchData],
                                            parameters: ContactModuleParameters,
                                            locale: Locale,
                                            delegate: ContactViewModelDelegate?,
                                            commandFactory: WalletCommandFactoryProtocol)
    -> [WalletViewModelProtocol] {
        items.compactMap {
            itemViewModelFactory.createContactViewModelFromContact($0,
                                                                   parameters: parameters,
                                                                   locale: locale,
                                                                   delegate: delegate,
                                                                   commandFactory: commandFactory)
        }
    }

    func createBarActionForAccountId(_ parameters: ContactModuleParameters,
                                     locale: Locale,
                                     commandFactory: WalletCommandFactoryProtocol)
    -> WalletBarActionViewModelProtocol? {
        guard let icon = R.image.iconScanQr() else {
            return nil
        }

        let command = commandFactory.prepareScanReceiverCommand()
        let viewModel = WalletBarActionViewModel(displayType: .icon(icon),
                                                 command: command)
        return viewModel
    }
}
