import Foundation
import SoraFoundation
import CommonWallet

final class ContactsPresenter {
    // MARK: Private properties

    private weak var view: ContactsViewInput?
    private let router: ContactsRouterInput
    private let interactor: ContactsInteractorInput
    private let viewModelFactory: AddressBookViewModelFactoryProtocol
    private let moduleOutput: ContactsModuleOutput
    private let chain: ChainModel
    private let wallet: MetaAccountModel

    // MARK: - Constructors

    init(
        interactor: ContactsInteractorInput,
        router: ContactsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: AddressBookViewModelFactoryProtocol,
        moduleOutput: ContactsModuleOutput,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
        self.chain = chain
        self.wallet = wallet

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - ContactsViewOutput

extension ContactsPresenter: ContactsViewOutput {
    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCreateButton() {
        router.createContact(address: nil, chain: chain, wallet: wallet, output: self, view: view)
    }

    func didLoad(view: ContactsViewInput) {
        self.view = view
        interactor.setup(with: self)
        view.didReceive(locale: selectedLocale)
    }

    func didSelect(address: String) {
        moduleOutput.didSelect(address: address)
        router.dismiss(view: view)
    }
}

// MARK: - ContactsInteractorOutput

extension ContactsPresenter: ContactsInteractorOutput {
    func didReceive(savedContacts: [Contact], recentContacts: [ContactType]) {
        let sections = viewModelFactory.buildCellViewModels(
            savedContacts: savedContacts,
            recentContacts: recentContacts,
            cellsDelegate: self,
            locale: selectedLocale
        )
        view?.didReceive(sections: sections)

        view?.didStopLoading()
    }

    func didReceiveError(_ error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }
}

// MARK: - Localizable

extension ContactsPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension ContactsPresenter: ContactsModuleInput {}

extension ContactsPresenter: ContactTableCellModelDelegate {
    func addContact(address: String) {
        router.createContact(
            address: address,
            chain: chain,
            wallet: wallet,
            output: self,
            view: view
        )
    }
}

extension ContactsPresenter: CreateContactModuleOutput {
    func didCreate(contact: Contact) {
        interactor.save(contact: contact)
    }
}
