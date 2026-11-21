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

    private var isExporting = false
    private var isLeaving = false
    private var isDeparturePending = false
    private var warningPresented = false
    private var deferredExport: Result<[RestoreJson], Error>?
    /// Encrypted keystore files written for this screen and not yet handed to the share
    /// screen, which removes the files it receives. These are removed when this screen goes.
    private var unclaimedFiles: Set<URL> = []

    let flow: ExportFlow

    init(flow: ExportFlow, localizationManager: LocalizationManagerProtocol) {
        self.flow = flow
        self.localizationManager = localizationManager
    }

    deinit {
        unclaimedFiles.forEach { SensitiveExportFiles.remove($0) }
    }
}

extension AccountExportPasswordPresenter: AccountExportPasswordPresenterProtocol {
    func setup() {
        view?.setPasswordInputViewModel(passwordInputViewModel)
        view?.setPasswordConfirmationViewModel(confirmationViewModel)
    }

    func didAppearView() {
        guard !warningPresented, !isLeaving, !isDeparturePending else { return }
        warningPresented = true
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(
            title: cancelTitle,
            handlerAfterDismissal: true,
            beforeDismissal: { [weak self] in self?.didLeaveView() },
            handler: { [weak self] in self?.wireframe.back(from: self?.view) }
        )

        let proceedTitle = R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages)
        let proceedAction = SheetAlertPresentableAction(title: proceedTitle, style: .pinkBackgroundWhiteText)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [proceedAction, cancelAction],
            closeAction: nil,
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    func willLeaveView() {
        isDeparturePending = true
        view?.setExporting(true)
    }

    func didCancelLeavingView() {
        guard !isLeaving else { return }
        isDeparturePending = false
        view?.setExporting(isExporting)
        guard let result = deferredExport else { return }
        deferredExport = nil
        switch result {
        case let .success(jsons): didExport(jsons: jsons)
        case let .failure(error): didReceive(error: error)
        }
    }

    func didLeaveView() {
        isLeaving = true
        deferredExport = nil
        unclaimedFiles.forEach { SensitiveExportFiles.remove($0) }
        unclaimedFiles.removeAll()
    }

    func proceed() {
        guard !isLeaving, !isDeparturePending, !isExporting else { return }
        let password = passwordInputViewModel.inputHandler.normalizedValue

        // The file holds the account's secret key encrypted with this password, so it
        // needs the same minimum as a Google Drive backup to resist offline guessing.
        guard NSPredicate.backupPassword.evaluate(with: password) else {
            view?.set(error: .passwordTooShort)
            return
        }

        guard password == confirmationViewModel.inputHandler.normalizedValue else {
            view?.set(error: .passwordMismatch)
            return
        }

        isExporting = true
        view?.setExporting(true)
        switch flow {
        case let .single(chain, address, wallet):
            interactor.exportAccount(
                address: address,
                password: password,
                chain: chain,
                wallet: wallet
            )
        case let .multiple(wallet, _):
            interactor.exportWallet(
                wallet: wallet,
                accounts: flow.exportingAccounts,
                password: password
            )
        }
    }
}

extension AccountExportPasswordPresenter: AccountExportPasswordInteractorOutputProtocol {
    func didExport(jsons: [RestoreJson]) {
        unclaimedFiles.formUnion(jsons.map(\.fileURL))
        guard finishExport(.success(jsons)) else {
            if isLeaving { didLeaveView() }
            return
        }
        hand(jsons)
        wireframe.showJSONExport(jsons, flow: flow, from: view)
    }

    func didReceive(error: Error) {
        if let batch = error as? AccountExportBatchError {
            unclaimedFiles.formUnion(batch.available.map(\.fileURL))
        }
        guard finishExport(.failure(error)) else {
            if isLeaving { didLeaveView() }
            return
        }
        if let batch = error as? AccountExportBatchError {
            presentIncompleteExport(batch)
            return
        }
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}

private extension AccountExportPasswordPresenter {
    func finishExport(_ result: Result<[RestoreJson], Error>) -> Bool {
        guard !isLeaving else { return false }
        if isDeparturePending {
            if deferredExport == nil { deferredExport = result }
            return false
        }
        isExporting = false
        view?.setExporting(false)
        return true
    }

    /// The share screen owns these files from now on and removes them when it closes.
    func hand(_ jsons: [RestoreJson]) {
        unclaimedFiles.subtract(jsons.map(\.fileURL))
    }

    func presentIncompleteExport(_ error: AccountExportBatchError) {
        let locale = localizationManager.selectedLocale
        let path = Bundle.main.path(forResource: localizationManager.selectedLocalization, ofType: "lproj")
            ?? Bundle.main.path(forResource: "en", ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? .main
        func text(_ key: String) -> String {
            bundle.localizedString(forKey: "export.json.partial." + key, value: nil, table: "Localizable")
        }
        let accounts = error.unavailable.map { info in
            let address = try? AddressFactory.address(for: info.account.accountId, chain: info.chain)
            return info.chain.name + (address.map { " · " + $0 } ?? "")
        }.joined(separator: "\n")
        let actions: [SheetAlertPresentableAction] = error.available.isEmpty ? [] : [
            SheetAlertPresentableAction(
                title: text("action"),
                style: .pinkBackgroundWhiteText,
                handlerAfterDismissal: true
            ) { [weak self] in
                guard let self, !self.isLeaving, !self.isDeparturePending else { return }
                self.hand(error.available)
                self.wireframe.showJSONExport(error.available, flow: self.flow, from: self.view)
            }
        ]
        let viewModel = SheetAlertPresentableViewModel(
            title: text("title"),
            message: String(format: text("message"), locale: locale, accounts),
            actions: actions,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )
        wireframe.present(viewModel: viewModel, from: view)
    }
}
