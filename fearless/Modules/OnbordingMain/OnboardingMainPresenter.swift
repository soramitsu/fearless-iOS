import Foundation
import SSFCloudStorage

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    private let wireframe: OnboardingMainWireframeProtocol
    private let interactor: OnboardingMainInteractorInputProtocol
    private let appVersionObserver: AppVersionObserver

    private let legalData: LegalData
    private let locale: Locale

    init(
        legalData: LegalData,
        locale: Locale,
        appVersionObserver: AppVersionObserver,
        wireframe: OnboardingMainWireframeProtocol,
        interactor: OnboardingMainInteractorInputProtocol
    ) {
        self.legalData = legalData
        self.locale = locale
        self.appVersionObserver = appVersionObserver
        self.wireframe = wireframe
        self.interactor = interactor
    }

    private func showGoogleIssueAlert() {
        let title = R.string.localizable
            .noAccessToGoogle(preferredLanguages: locale.rLanguages)
        let retryTitle = R.string.localizable
            .tryAgain(preferredLanguages: locale.rLanguages)
        let retryAction = SheetAlertPresentableAction(
            title: retryTitle,
            style: .pinkBackgroundWhiteText,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            self?.interactor.activateGoogleBackup()
        }
        wireframe.present(
            message: nil,
            title: title,
            closeAction: nil,
            from: view,
            actions: [retryAction]
        )
    }

    private func activateGoogleBackup() {
        view?.didStartLoading()
        interactor.activateGoogleBackup()
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func setup() {
        interactor.setup()

        appVersionObserver.checkVersion(from: view, callback: nil)
    }

    func activateTerms() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.termsUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.privacyPolicyUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activateSignup() {
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        let preferredLanguages = locale.rLanguages

        let mnemonicTitle = R.string.localizable
            .googleBackupChoiceMnemonic(preferredLanguages: preferredLanguages)
        let mnemonicAction = SheetAlertPresentableAction(
            title: mnemonicTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAccountRestore(defaultSource: .mnemonic, from: self.view)
        }

        let rawTitle = R.string.localizable
            .googleBackupChoiceRaw(preferredLanguages: preferredLanguages)
        let rawAction = SheetAlertPresentableAction(
            title: rawTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAccountRestore(defaultSource: .seed, from: self.view)
        }

        let jsonTitle = R.string.localizable
            .googleBackupChoiceJson(preferredLanguages: preferredLanguages)
        let jsonAction = SheetAlertPresentableAction(
            title: jsonTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAccountRestore(defaultSource: .keystore, from: self.view)
        }

        let googleButton = TriangularedButton()
        googleButton.imageWithTitleView?.iconImage = R.image.googleBackup()
        googleButton.applyDisabledStyle()
        let googleTitle = R.string.localizable
            .googleBackupChoiceGoogle(preferredLanguages: preferredLanguages)
        let googleAction = SheetAlertPresentableAction(
            title: googleTitle,
            button: googleButton
        ) { [weak self] in
            guard let self = self else { return }
            self.activateGoogleBackup()
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: preferredLanguages)
        let cancelAction = SheetAlertPresentableAction(
            title: cancelTitle,
            style: .pinkBackgroundWhiteText
        )

        let title = R.string.localizable
            .googleBackupChoiceTitle(preferredLanguages: preferredLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [mnemonicAction, rawAction, jsonAction, googleAction, cancelAction],
            closeAction: nil,
            icon: nil
        )

        wireframe.present(viewModel: viewModel, from: view)
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestKeystoreImport() {
        wireframe.showKeystoreImport(from: view)
    }

    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>) {
        view?.didStopLoading()
        switch result {
        case let .success(accounts):
            if accounts.isNotEmpty {
                wireframe.showBackupSelectWallet(
                    accounts: accounts,
                    from: view
                )
            } else {
                wireframe.showCreateFlow(from: view)
            }
        case .failure:
            showGoogleIssueAlert()
        }
    }
}
