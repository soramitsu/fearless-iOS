import Foundation
import SoraFoundation

final class AccountInfoPresenter {
    weak var view: AccountInfoViewProtocol?
    var wireframe: AccountInfoWireframeProtocol!
    var interactor: AccountInfoInteractorInputProtocol!

    let localizationManager: LocalizationManagerProtocol

    private let accountId: String

    init(accountId: String,
         localizationManager: LocalizationManagerProtocol) {
        self.accountId = accountId
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
        interactor.setup(accountId: accountId)
    }

    func activateClose() {
        wireframe.close(view: view)
    }

    func activateExport() {
        wireframe.showExport(for: accountId, from: view)
    }

    func activateCopyAddress() {
        let locale = localizationManager.selectedLocale

        let selectTitle = R.string.localizable.commonSelectOption(preferredLanguages: locale.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)

        let copyTitle = R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages)

        let copyAction = AlertPresentableAction(title: copyTitle) { [weak self] in
            UIPasteboard.general.string = self?.accountId
        }

        let viewModel = AlertPresentableViewModel(title: selectTitle,
                                                  message: nil,
                                                  actions: [copyAction],
                                                  closeAction: closeTitle)

        wireframe.present(viewModel: viewModel,
                          style: .actionSheet,
                          from: view)
    }

    func save(username: String) {
        interactor.save(username: username, accountId: accountId)
    }
}

extension AccountInfoPresenter: AccountInfoInteractorOutputProtocol {
    func didReceive(accountItem: ManagedAccountItem) {
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
