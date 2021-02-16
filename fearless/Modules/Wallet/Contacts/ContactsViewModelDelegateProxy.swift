import Foundation
import RobinHood
import CommonWallet
import CoreData

class ContactsViewModelDelegateProxy<T: Identifiable, U: NSManagedObject>: ContactViewModelDelegate {
    private var locale: Locale
    private var storage: CoreDataRepository<T, U>
    private var commandFactory: WalletCommandFactoryProtocol

    private weak var callee: ContactViewModelDelegate?
    let logger = Logger.shared

    init(callee: ContactViewModelDelegate?,
         storage: CoreDataRepository<T, U>,
         commandFactory: WalletCommandFactoryProtocol,
         locale: Locale
    ) {
        self.callee = callee
        self.locale = locale
        self.storage = storage
        self.commandFactory = commandFactory
    }

    func didSelect(contact: ContactViewModelProtocol) {
        let nextAction = {
            self.callee?.didSelect(contact: contact)
            return
        }

        let cancelAction = {
            let hideCommand = self.commandFactory.prepareHideCommand(with: .pop)
            try? hideCommand.execute()
        }

        let phishingCheckExecutor: PhishingCheckExecutorProtocol =
            PhishingCheckExecutor(commandFactory: commandFactory,
                                  storage: storage,
                                  nextAction: nextAction,
                                  cancelAction: cancelAction,
                                  locale: locale)

        phishingCheckExecutor.checkPhishing(
            publicKey: contact.accountId,
            walletAddress: contact.firstName)
    }
}
