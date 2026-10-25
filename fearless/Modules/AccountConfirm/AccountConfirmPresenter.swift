import Foundation
import SoraFoundation

final class AccountConfirmPresenter {
    weak var view: AccountConfirmViewProtocol?
    var wireframe: AccountConfirmWireframeProtocol
    var interactor: AccountConfirmInteractorInputProtocol
    private var isLeaving = false
    private var isDeparturePending = false
    private var deferredConfirmation: Result<Void, Error>?
    private var confirming = false

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
            guard let self, !self.isLeaving, !self.isDeparturePending, !self.confirming else { return }
            self.interactor.skipConfirmation()
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
    func willLeaveView() {
        isDeparturePending = true
    }

    func didCancelLeavingView() {
        guard !isLeaving else { return }
        isDeparturePending = false
        guard let result = deferredConfirmation else { return }
        deferredConfirmation = nil
        switch result {
        case .success: didCompleteConfirmation()
        case let .failure(error): didReceive(error: error)
        }
    }

    func didLeaveView() {
        isLeaving = true
        deferredConfirmation = nil
    }

    func didLoad(view: AccountConfirmViewProtocol) {
        self.view = view
        interactor.requestWords()
    }

    func requestWords() {
        guard !isLeaving, !isDeparturePending, !confirming else { return }
        interactor.requestWords()
    }

    func confirm(words: [String]) {
        guard !isLeaving, !isDeparturePending, !confirming else { return }
        confirming = true
        interactor.confirm(words: words)
    }

    func skip() {
        guard !isLeaving, !isDeparturePending, !confirming else { return }
        showNotBackedupAlert()
    }
}

extension AccountConfirmPresenter: AccountConfirmInteractorOutputProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
        guard !isLeaving else { return }
        confirming = false
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
        guard !isLeaving else { return }
        if isDeparturePending {
            if deferredConfirmation == nil { deferredConfirmation = .success(()) }
            return
        }
        isLeaving = true
        wireframe.proceed(from: view, flow: interactor.flow)
    }

    func didReceive(error: Error) {
        guard !isLeaving else { return }
        if isDeparturePending {
            if deferredConfirmation == nil { deferredConfirmation = .failure(error) }
            return
        }
        confirming = false
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
