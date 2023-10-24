import Foundation
import SoraFoundation

final class AccountConfirmPresenter {
    weak var view: AccountConfirmViewProtocol?
    var wireframe: AccountConfirmWireframeProtocol
    var interactor: AccountConfirmInteractorInputProtocol

    init(
        interactor: AccountConfirmInteractorInputProtocol,
        wireframe: AccountConfirmWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func showNotBackedupAlert() {
        let cancelActionTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(title: cancelActionTitle)

        let confirmActionTitle = R.string.localizable
            .backupNotBackedUpConfirm(preferredLanguages: selectedLocale.rLanguages)
        let confirmAction = SheetAlertPresentableAction(
            title: confirmActionTitle,
            style: .pinkBackgroundWhiteText,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            self?.interactor.skipConfirmation()
        }
        let action = [cancelAction, confirmAction]
        let alertTitle = R.string.localizable
            .backupNotBackedUpTitle(preferredLanguages: selectedLocale.rLanguages)
        let alertMessage = R.string.localizable
            .backupNotBackedUpMessage(preferredLanguages: selectedLocale.rLanguages)
        let alertViewModel = SheetAlertPresentableViewModel(
            title: alertTitle,
            message: alertMessage,
            actions: action,
            closeAction: nil,
            actionAxis: .horizontal
        )
        wireframe.present(viewModel: alertViewModel, from: view)
    }
}

extension AccountConfirmPresenter: AccountConfirmPresenterProtocol {
    func didLoad(view: AccountConfirmViewProtocol) {
        self.view = view
        interactor.requestWords()
    }

    func requestWords() {
        interactor.requestWords()
    }

    func confirm(words: [String]) {
        interactor.confirm(words: words)
    }

    func skip() {
        showNotBackedupAlert()
    }
}

extension AccountConfirmPresenter: AccountConfirmInteractorOutputProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
        if afterConfirmationFail {
            let locale = localizationManager?.selectedLocale
            let title = R.string.localizable
                .confirmMnemonicMismatchErrorTitle(preferredLanguages: locale?.rLanguages)
            let message = R.string.localizable
                .confirmMnemonicMismatchErrorMessage(preferredLanguages: locale?.rLanguages)
            let close = R.string.localizable.commonOk(preferredLanguages: locale?.rLanguages)

            wireframe.present(
                message: message,
                title: title,
                closeAction: close,
                from: view
            )
        }

        view?.didReceive(words: words, afterConfirmationFail: afterConfirmationFail)
    }

    func didCompleteConfirmation() {
        wireframe.proceed(from: view, flow: interactor.flow)
    }

    func didReceive(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(
            error: CommonError.undefined,
            from: view,
            locale: locale
        )
    }
}

extension AccountConfirmPresenter: Localizable {
    func applyLocalization() {}
}
