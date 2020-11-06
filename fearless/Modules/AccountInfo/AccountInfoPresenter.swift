import Foundation
import SoraFoundation

final class AccountInfoPresenter {
    weak var view: AccountInfoViewProtocol?
    var wireframe: AccountInfoWireframeProtocol!
    var interactor: AccountInfoInteractorInputProtocol!

    let localizationManager: LocalizationManagerProtocol

    private let address: String

    private var accountItem: ManagedAccountItem?

    init(address: String,
         localizationManager: LocalizationManagerProtocol) {
        self.address = address
        self.localizationManager = localizationManager
    }

    private func updateView(accountItem: ManagedAccountItem) {
        let inputHandling = InputHandler(value: accountItem.username, predicate: NSPredicate.notEmpty)
        let usernameViewModel = InputViewModel(inputHandler: inputHandling)

        view?.set(usernameViewModel: usernameViewModel)

        view?.set(address: accountItem.address)
        view?.set(networkType: accountItem.networkType)
    }
}

extension AccountInfoPresenter: AccountInfoPresenterProtocol {
    func setup() {
        interactor.setup(address: address)
    }

    func activateClose() {
        wireframe.close(view: view)
    }

    func activateExport() {
        guard let accountItem = accountItem else {
            return
        }

        interactor.requestExportOptions(accountItem: accountItem)
    }

    func activateCopyAddress() {
        UIPasteboard.general.string = address

        let locale = localizationManager.selectedLocale
        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    func save(username: String) {
        interactor.save(username: username, address: address)
    }
}

extension AccountInfoPresenter: AccountInfoInteractorOutputProtocol {
    func didReceive(exportOptions: [ExportOption]) {
        wireframe.showExport(for: address,
                             options: exportOptions,
                             locale: localizationManager.selectedLocale,
                             from: view)
    }

    func didReceive(accountItem: ManagedAccountItem) {
        self.accountItem = accountItem

        updateView(accountItem: accountItem)
    }

    func didSave(username: String) {
        wireframe.close(view: view)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(error: CommonError.undefined,
                                  from: view,
                                  locale: localizationManager.selectedLocale)
        }
    }
}
