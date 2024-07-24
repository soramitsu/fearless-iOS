import Foundation

protocol AddressBookViewModelFactoryProtocol {
    func buildCellViewModels(
        savedContacts: [Contact],
        recentContacts: [ContactType],
        cellsDelegate: ContactTableCellModelDelegate,
        locale: Locale
    ) -> [ContactsTableSectionModel]
}

struct ContactsTableSectionModel {
    let name: String
    let cellViewModels: [ContactTableCellModel]
}

final class AddressBookViewModelFactory: AddressBookViewModelFactoryProtocol {
    private let accountScoreFetcher: AccountStatisticsFetching

    init(accountScoreFetcher: AccountStatisticsFetching) {
        self.accountScoreFetcher = accountScoreFetcher
    }

    func buildCellViewModels(
        savedContacts: [Contact],
        recentContacts: [ContactType],
        cellsDelegate: ContactTableCellModelDelegate,
        locale: Locale
    ) -> [ContactsTableSectionModel] {
        let recentContactsViewModels = recentContacts.map { contactType in

            let accountScoreViewModel = AccountScoreViewModel(fetcher: accountScoreFetcher, address: contactType.address)

            return ContactTableCellModel(
                contactType: contactType,
                delegate: cellsDelegate,
                accountScoreViewModel: accountScoreViewModel
            )
        }
        let recentContactsSection = ContactsTableSectionModel(
            name: R.string.localizable.contactsRecent(preferredLanguages: locale.rLanguages),
            cellViewModels: recentContactsViewModels
        )

        let contactsFirstLetters: [Character] = Array(Set(savedContacts
                .sorted { $0.name < $1.name }
                .compactMap { contact in
                    contact.name.first
                }
        ))
        let savedContactsSections: [ContactsTableSectionModel] = contactsFirstLetters.map { firstLetter in
            let contacts = savedContacts.filter { contact in
                contact.name.first?.lowercased() == firstLetter.lowercased()
            }
            let cellModels = contacts.map { contact in
                let accountScoreViewModel = AccountScoreViewModel(fetcher: accountScoreFetcher, address: contact.address)

                return ContactTableCellModel(contactType: .saved(contact), delegate: cellsDelegate, accountScoreViewModel: accountScoreViewModel)
            }
            return ContactsTableSectionModel(name: String(firstLetter), cellViewModels: cellModels)
        }
        if savedContacts.isEmpty, recentContacts.isEmpty {
            return []
        }
        return ([recentContactsSection] + savedContactsSections).filter { $0.cellViewModels.isNotEmpty }
    }
}
