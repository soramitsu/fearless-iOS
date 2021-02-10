import Foundation
import CommonWallet

final class ContactViewModel: ContactsLocalSearchResultProtocol {
    var cellReuseIdentifier: String { ContactsConstants.contactCellIdentifier }
    var itemHeight: CGFloat { ContactsConstants.contactCellHeight }

    let firstName: String
    let lastName: String
    let accountId: String
    let image: UIImage?
    let name: String

    weak var delegate: ContactViewModelDelegate?

    init(firstName: String,
         lastName: String,
         accountId: String,
         image: UIImage?,
         name: String,
         delegate: ContactViewModelDelegate?) {
        self.firstName = firstName
        self.lastName = lastName
        self.accountId = accountId
        self.image = image
        self.name = name
        self.delegate = delegate
    }
}

extension ContactViewModel: WalletCommandProtocol {
    var command: WalletCommandProtocol? { self }

    func execute() throws {
        // TODO: Insert alert here
        delegate?.didSelect(contact: self)
    }
}
