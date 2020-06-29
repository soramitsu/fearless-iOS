import Foundation
import SoraFoundation

final class AccessRestorePresenter {
    static let maxMnemonicLength: Int = 250
    static let mnemonicSize: Int = 24

    weak var view: AccessRestoreViewProtocol?
    var interactor: AccessRestoreInteractorInputProtocol!
    var wireframe: AccessRestoreWireframeProtocol!

    var model: InputViewModel = {
        let inputHandler = InputHandler(maxLength: AccessRestorePresenter.maxMnemonicLength,
                                        validCharacterSet: CharacterSet.englishMnemonic)
        return InputViewModel(inputHandler: inputHandler)
    }()
}

extension AccessRestorePresenter: AccessRestorePresenterProtocol {
    func load() {
        view?.didReceiveView(model: model)
    }

    func activateAccessRestoration() {
        let mnemonicSize = model.inputHandler.normalizedValue
            .components(separatedBy: CharacterSet.whitespaces).count
        if mnemonicSize > AccessRestorePresenter.mnemonicSize {
            let languages = localizationManager?.selectedLocale.rLanguages
            let message = R.string.localizable.accessRestoreWordsErrorMessage(preferredLanguages: languages)
            let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages)

            wireframe.present(message: message,
                              title: title,
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            return
        }

        view?.didStartLoading()
        interactor.restoreAccess(mnemonic: model.inputHandler.value)
    }
}

extension AccessRestorePresenter: AccessRestoreInteractorOutputProtocol {
    func didRestoreAccess(from mnemonic: String) {
        view?.didStopLoading()
        wireframe.showNext(from: view)
    }

    func didReceiveRestoreAccess(error: Error) {
        view?.didStopLoading()

        let locale = localizationManager?.selectedLocale

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }

        let languages = locale?.rLanguages

        wireframe.present(message: R.string.localizable
            .accessRestorePhraseErrorMessage(preferredLanguages: languages),
                          title: R.string.localizable
                            .commonErrorGeneralTitle(preferredLanguages: languages),
                          closeAction: R.string.localizable
                            .commonClose(preferredLanguages: languages),
                          from: view)
    }
}

extension AccessRestorePresenter: Localizable {
    func applyLocalization() {}
}
