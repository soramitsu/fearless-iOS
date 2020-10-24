import Foundation
import CommonWallet

final class ContactsListViewModelFactory: ContactsListViewModelFactoryProtocol {
    private var itemViewModelFactory = ContactsViewModelFactory()

    func createContactViewModelListFromItems(_ items: [SearchData],
                                             accountId: String,
                                             assetId: String,
                                             locale: Locale,
                                             delegate: ContactViewModelDelegate?) -> [ContactSectionViewModelProtocol] {
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
                                                                accountId: accountId,
                                                                assetId: assetId,
                                                                locale: locale,
                                                                delegate: delegate)

            let sectionTitle = R.string.localizable
                .walletSearchAccounts(preferredLanguages: locale.rLanguages)
            let section = ContactSectionViewModel(title: sectionTitle,
                                                  items: viewModels)
            sections.append(section)
        }

        if !remoteItems.isEmpty {
            let viewModels = createSearchViewModelListFromItems(remoteItems,
                                                                accountId: accountId,
                                                                assetId: assetId,
                                                                locale: locale,
                                                                delegate: delegate)
            let sectionTitle = R.string.localizable
                .walletSearchContacts(preferredLanguages: locale.rLanguages)
            let section = ContactSectionViewModel(title: sectionTitle,
                                                  items: viewModels)
            sections.append(section)
        }

        return sections
    }

    func createSearchViewModelListFromItems(_ items: [SearchData],
                                            accountId: String,
                                            assetId: String,
                                            locale: Locale,
                                            delegate: ContactViewModelDelegate?) -> [WalletViewModelProtocol] {
        items.compactMap {
            itemViewModelFactory.createContactViewModelFromContact($0,
                                                                   accountId: accountId,
                                                                   assetId: assetId,
                                                                   delegate: delegate)
        }
    }

    func createBarActionForAccountId(_ accountId: String, assetId: String) -> WalletBarActionViewModelProtocol? {
        nil
    }
}
