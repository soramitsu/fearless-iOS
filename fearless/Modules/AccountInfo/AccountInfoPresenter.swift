import Foundation
import SoraFoundation
import FearlessUtils

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
        usernameViewModel.inputHandler.addObserver(self)

        view?.set(usernameViewModel: usernameViewModel)

        view?.set(address: accountItem.address)
        view?.set(networkType: accountItem.networkType.chain)
        view?.set(cryptoType: accountItem.cryptoType)
    }

    private func copyAddress() {
        UIPasteboard.general.string = address

        let locale = localizationManager.selectedLocale
        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
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

        interactor.flushPendingUsername()

        interactor.requestExportOptions(accountItem: accountItem)
    }

    func activateAddressAction() {
        guard let accountItem = accountItem else {
            return
        }

        let locale = localizationManager.selectedLocale

        let copyClosure: () -> Void = { [weak self] in
            self?.copyAddress()
        }

        wireframe.presentAddressOptions(address,
                                        chain: accountItem.networkType.chain,
                                        locale: locale,
                                        copyClosure: copyClosure,
                                        from: view)
    }

    func finalizeUsername() {
        interactor.flushPendingUsername()
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

    func didSave(username: String) {}

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(error: CommonError.undefined,
                                  from: view,
                                  locale: localizationManager.selectedLocale)
        }
    }
}

extension AccountInfoPresenter: InputHandlingObserver {
    func didChangeInputValue(_ handler: InputHandling, from oldValue: String) {
        if handler.completed {
            let username = handler.normalizedValue
            interactor.save(username: username, address: address)
        }
    }
}
