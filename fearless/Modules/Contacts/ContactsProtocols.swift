import Foundation
import SSFModels

typealias ContactsModuleCreationResult = (view: ContactsViewInput, input: ContactsModuleInput)

protocol ContactsViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(sections: [ContactsTableSectionModel])
    func didReceive(locale: Locale)
    func didReceive(source: ContactSource)
}

protocol ContactsViewOutput: AnyObject {
    func didLoad(view: ContactsViewInput)
    func didTapBackButton()
    func didTapCreateButton()
    func didSelect(address: String)
}

protocol ContactsInteractorInput: AnyObject {
    func setup(with output: ContactsInteractorOutput)
    func save(contact: Contact)
}

protocol ContactsInteractorOutput: AnyObject {
    func didReceive(savedContacts: [Contact], recentContacts: [ContactType])
    func didReceiveError(_ error: Error)
}

protocol ContactsRouterInput: PresentDismissable, ErrorPresentable, SheetAlertPresentable {
    func createContact(
        address: String?,
        chain: ChainModel,
        output: CreateContactModuleOutput,
        view: ControllerBackedProtocol?
    )
}

protocol ContactsModuleInput: AnyObject {}

protocol ContactsModuleOutput: AnyObject {
    func didSelect(address: String)
}
