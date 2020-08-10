import Foundation
import SoraFoundation

final class AccountConfirmPresenter {
    weak var view: AccountConfirmViewProtocol?
    var wireframe: AccountConfirmWireframeProtocol!
    var interactor: AccountConfirmInteractorInputProtocol!
}

extension AccountConfirmPresenter: AccountConfirmPresenterProtocol {
    func setup() {
        interactor.requestWords()
    }

    func requestWords() {
        interactor.requestWords()
    }

    func confirm(words: [String]) {
        interactor.confirm(words: words)
    }
}

extension AccountConfirmPresenter: AccountConfirmInteractorOutputProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
        view?.didReceive(words: words, afterConfirmationFail: afterConfirmationFail)
    }

    func didCompleteConfirmation() {
        wireframe.proceed()
    }

    func didReceive(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined,
                              from: view,
                              locale: locale)
    }
}

extension AccountConfirmPresenter: Localizable {
    func applyLocalization() {}
}
