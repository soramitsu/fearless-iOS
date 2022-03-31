import Foundation
import SoraFoundation

final class AccountExportPasswordPresenter {
    weak var view: AccountExportPasswordViewProtocol?
    var wireframe: AccountExportPasswordWireframeProtocol!
    var interactor: AccountExportPasswordInteractorInputProtocol!

    private let passwordInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    private let confirmationViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    let localizationManager: LocalizationManagerProtocol

    let flow: ExportFlow

    init(flow: ExportFlow, localizationManager: LocalizationManagerProtocol) {
        self.flow = flow
        self.localizationManager = localizationManager
    }
}

extension AccountExportPasswordPresenter: AccountExportPasswordPresenterProtocol {
    func setup() {
        view?.setPasswordInputViewModel(passwordInputViewModel)
        view?.setPasswordConfirmationViewModel(confirmationViewModel)
    }

    func proceed() {
        let password = passwordInputViewModel.inputHandler.normalizedValue

        guard password == confirmationViewModel.inputHandler.normalizedValue else {
            view?.set(error: .passwordMismatch)
            return
        }

        switch flow {
        case let .single(chain, address):
            interactor.exportAccount(address: address, password: password, chain: chain)
        case let .multiple(account):
            interactor.exportWallet(account, password: password)
        }
    }
}

extension AccountExportPasswordPresenter: AccountExportPasswordInteractorOutputProtocol {
    func didExport(jsons: [RestoreJson]) {
        wireframe.showJSONExport(jsons, from: view)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
