import Foundation
import SoraFoundation

final class AccessBackupPresenter {
    weak var view: AccessBackupViewProtocol?
    var interactor: AccessBackupInteractorInputProtocol!
    var wireframe: AccessBackupWireframeProtocol!

    var mnemonic: String?
}

extension AccessBackupPresenter: AccessBackupPresenterProtocol {
    func setup() {
        guard let mnemonic = mnemonic else {
            interactor.load()
            return
        }

        view?.didReceiveBackup(mnemonic: mnemonic)
    }

    func activateSharing() {
        guard let mnemonic = mnemonic else {
            return
        }

        let languages = localizationManager?.preferredLocalizations
        let subject = R.string.localizable
            .commonPassphraseSharingSubject(preferredLanguages: languages)
        let source = TextSharingSource(message: mnemonic,
                                       subject: subject)

        wireframe.share(source: source, from: view, with: nil)
    }

    func activateNext() {
        wireframe.showNext(from: view)
    }
}

extension AccessBackupPresenter: AccessBackupInteractorOutputProtocol {
    func didLoad(mnemonic: String) {
        self.mnemonic = mnemonic
        view?.didReceiveBackup(mnemonic: mnemonic)
    }

    func didReceive(error: Error) {
        if let interactorError = error as? AccessBackupInteractorError {
            let languages = localizationManager?.preferredLocalizations
            switch interactorError {
            case .loading:
                wireframe.present(message: R.string.localizable
                    .accessBackupErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable
                                    .accessBackupLoadErrorTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: languages),
                                  from: view)
            }
        }
    }
}

extension AccessBackupPresenter: Localizable {
    func applyLocalization() {}
}
