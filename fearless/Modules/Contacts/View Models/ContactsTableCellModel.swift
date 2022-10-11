import UIKit

protocol ContactTableCellModelDelegate: AnyObject {
    func addContact(address: String)
}

enum ContactType {
    case saved(Contact)
    case unsaved(String)

    var address: String {
        switch self {
        case let .saved(contact):
            return contact.address
        case let .unsaved(address):
            return address
        }
    }
}

struct ContactTableCellModel {
    let contactType: ContactType
    weak var delegate: ContactTableCellModelDelegate?
}

extension ContactTableCellModel: ContactTableCellDelegate {
    func didTapAddButton() {
        delegate?.addContact(address: contactType.address)
    }
}
