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
    func buildCellViewModels(
        savedContacts: [Contact],
        recentContacts: [ContactType],
        cellsDelegate: ContactTableCellModelDelegate,
        locale: Locale
    ) -> [ContactsTableSectionModel] {
        let recentContactsViewModels = recentContacts.map { contactType in
            ContactTableCellModel(
                contactType: contactType,
                delegate: cellsDelegate
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
                ContactTableCellModel(contactType: .saved(contact), delegate: cellsDelegate)
            }
            return ContactsTableSectionModel(name: String(firstLetter), cellViewModels: cellModels)
        }
        return [recentContactsSection] + savedContactsSections
    }
}
