import UIKit

protocol ContactTableCellModelDelegate: AnyObject {
    func addContact(address: String)
    func didTapAccountScore(address: String)
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

class ContactTableCellModel {
    let contactType: ContactType
    let accountScoreViewModel: AccountScoreViewModel?
    weak var delegate: ContactTableCellModelDelegate?

    init(contactType: ContactType, delegate: ContactTableCellModelDelegate?, accountScoreViewModel: AccountScoreViewModel?) {
        self.contactType = contactType
        self.delegate = delegate
        self.accountScoreViewModel = accountScoreViewModel
    }
}

extension ContactTableCellModel: ContactTableCellDelegate {
    func didTapAddButton() {
        delegate?.addContact(address: contactType.address)
    }

    func didTapAccountScore() {
        delegate?.didTapAccountScore(address: contactType.address)
    }
}
