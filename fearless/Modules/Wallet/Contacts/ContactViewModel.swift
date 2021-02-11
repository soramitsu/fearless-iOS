import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class ContactViewModel: ContactsLocalSearchResultProtocol {
    var cellReuseIdentifier: String { ContactsConstants.contactCellIdentifier }
    var itemHeight: CGFloat { ContactsConstants.contactCellHeight }

    let firstName: String
    let lastName: String
    let accountId: String
    let image: UIImage?
    let name: String
    let commandFactory: WalletCommandFactoryProtocol

    weak var delegate: ContactViewModelDelegate?

    init(firstName: String,
         lastName: String,
         accountId: String,
         image: UIImage?,
         name: String,
         delegate: ContactViewModelDelegate?,
         commandFactory: WalletCommandFactoryProtocol) {
        self.firstName = firstName
        self.lastName = lastName
        self.accountId = accountId
        self.image = image
        self.name = name
        self.delegate = delegate
        self.commandFactory = commandFactory
    }
}

extension ContactViewModel: WalletCommandProtocol {
    var command: WalletCommandProtocol? { self }

    func execute() throws {
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let fetchOperation = storage.fetchOperation(by: accountId,
                                                    options: RepositoryFetchOptions())
        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                self.handleAccountFetch(result: fetchOperation.result)
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [fetchOperation], in: .sync)
    }

    private func handleAccountFetch(result: Result<PhishingItem?, Error>?) {
        let logger = Logger.shared

        switch result {
        case .success(let account):
            guard account != nil else {
                delegate?.didSelect(contact: self)
                return
            }

            self.showWarning()

        case .failure(let error):
            logger.error(error.localizedDescription)

        case .none:
            logger.error("Scam account fetch operation cancelled")
        }
    }

    private func showWarning() {
        let locale = LocalizationManager.shared.selectedLocale

        let alertController = UIAlertController.phishingWarningAlert(onConfirm: { () -> Void in
            self.delegate?.didSelect(contact: self)
        }, onCancel: { () -> Void in
            let hideCommand = self.commandFactory.prepareHideCommand(with: .pop)
            try? hideCommand.execute()
        }, locale: locale,
        publicKey: accountId)

        let presentationCommand = commandFactory.preparePresentationCommand(for: alertController)
        presentationCommand.presentationStyle = .modal(inNavigation: false)

        try? presentationCommand.execute()
    }

}
