import Foundation
import SoraFoundation

final class ExportSeedPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportSeedWireframeProtocol!
    var interactor: ExportSeedInteractorInputProtocol!

    let flow: ExportFlow
    let localizationManager: LocalizationManager

    private var valueForBackup: [String]?
    /// Requested accounts whose raw seed is not shown. The wallet is never marked backed up
    /// while any is left, and the user is told which ones once the export warning is closed.
    private var notShown: [ExportSeedNotShown] = []
    private var isWarningOpen = false
    private var warningPresented = false
    private var isLeaving = false
    private var notShownNoticePresented = false
    private var backupPending = false
    private var backupAttempt: UUID?
    private var backupRecorded = false
    private var shareWarning: UUID?
    private var confirmedShareWarning: UUID?
    private var shareAttempt: UUID?

    init(flow: ExportFlow, localizationManager: LocalizationManager) {
        self.flow = flow
        self.localizationManager = localizationManager
    }

    func didTapStringExport(_ value: String?) {
        guard !isLeaving, !backupPending, !isWarningOpen, shareWarning == nil, shareAttempt == nil,
              let value = value else {
            return
        }

        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let warning = UUID()
        shareWarning = warning
        isWarningOpen = true
        let exportTitle = R.string.localizable.accountExportAction(preferredLanguages: locale.rLanguages)
        let exportAction = SheetAlertPresentableAction(
            title: exportTitle,
            handlerAfterDismissal: true,
            beforeDismissal: { [weak self] in
                guard self?.shareWarning == warning else { return }
                self?.confirmedShareWarning = warning
            },
            handler: { [weak self] in
                guard let self, self.shareWarning == warning, !self.isLeaving else { return }
                self.shareWarning = nil
                self.confirmedShareWarning = nil
                self.share(value)
            }
        )

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction],
            closeAction: cancelTitle,
            dismissCompletion: { [weak self] in
                guard let self, self.shareWarning == warning else { return }
                self.isWarningOpen = false
                if self.confirmedShareWarning != warning {
                    self.shareWarning = nil
                    self.presentNotShownIfNeeded()
                }
            },
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    func share(_ value: String) {
        guard !isLeaving, !backupPending, !isWarningOpen, shareWarning == nil, shareAttempt == nil else { return }
        let attempt = UUID()
        shareAttempt = attempt
        wireframe.share(source: TextSharingSource(message: value), from: view) { [weak self] completed in
            guard let self, self.shareAttempt == attempt, !self.isLeaving else { return }
            self.shareAttempt = nil
            if completed {
                self.checkBackuped(for: value)
            }
        }
    }

    private func checkBackuped(for value: String) {
        valueForBackup?.removeAll(where: { $0 == value })
        guard !isLeaving, case .multiple = flow, valueForBackup?.isEmpty == true, notShown.isEmpty else {
            return
        }
        recordBackupStatus()
    }

    private func recordBackupStatus() {
        guard !isLeaving, !backupPending, !backupRecorded else { return }
        backupPending = true
        let attempt = UUID()
        backupAttempt = attempt
        interactor.didBackupSeed(wallet: flow.wallet) { [weak self] result in
            guard let self, self.backupAttempt == attempt else { return }
            self.backupAttempt = nil
            self.backupPending = false
            if case .success = result {
                self.backupRecorded = true
            }
            guard !self.isLeaving else { return }
            if case .failure = result {
                let locale = self.localizationManager.selectedLocale
                self.wireframe.presentBackupStatusFailure(from: self.view, locale: locale) { [weak self] in
                    self?.recordBackupStatus()
                }
            }
        }
    }

    private func presentNotShownIfNeeded() {
        guard !isWarningOpen, !isLeaving, !notShownNoticePresented, !notShown.isEmpty else {
            return
        }
        notShownNoticePresented = true

        let languages = localizationManager.selectedLocale.rLanguages
        let networks = notShown.map(\.chain.name).joined(separator: "\n")
        let jsonAction = SheetAlertPresentableAction(
            title: R.string.localizable.backupWalletJson(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText,
            handlerAfterDismissal: true
        ) { [weak self] in
            guard let self, !self.isLeaving else {
                return
            }
            self.wireframe.showJsonExport(flow: self.flow, from: self.view)
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.exportSeedUnavailableTitle(preferredLanguages: languages),
            message: R.string.localizable.exportSeedPartialMessage(networks, preferredLanguages: languages),
            actions: [jsonAction],
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    private func warningDidClose() {
        isWarningOpen = false
        presentNotShownIfNeeded()
    }
}

extension ExportSeedPresenter: ExportGenericPresenterProtocol {
    func didLeaveView() {
        isLeaving = true
        shareWarning = nil
        confirmedShareWarning = nil
        shareAttempt = nil
    }

    func didLoadView() {
        guard !isLeaving, !warningPresented else { return }
        warningPresented = true
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let exportTitle = R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages)
        let exportAction = SheetAlertPresentableAction(title: exportTitle, style: .pinkBackgroundWhiteText)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(
            title: cancelTitle,
            handlerAfterDismissal: true,
            beforeDismissal: { [weak self] in self?.didLeaveView() },
            handler: { [weak self] in self?.wireframe.back(view: self?.view) }
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction, cancelAction],
            closeAction: nil,
            dismissCompletion: { [weak self] in self?.warningDidClose() },
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )

        isWarningOpen = true
        wireframe.present(viewModel: viewModel, from: view)
    }

    func setup() {
        // Hold recovery notices until the attached initial warning has closed.
        isWarningOpen = true
        switch flow {
        case let .single(chain, address, wallet):
            interactor.fetchExportDataForAddress(address, chain: chain, wallet: wallet)
        case let .multiple(wallet, _):
            interactor.fetchExportDataForWallet(wallet, accounts: flow.exportingAccounts)
        }
    }
}

extension ExportSeedPresenter: ExportSeedInteractorOutputProtocol {
    func didReceive(exportData: [ExportSeedData], notShown: [ExportSeedNotShown]) {
        self.notShown = notShown

        let viewModels = exportData.compactMap { seedData in
            ExportStringViewModel(
                option: .seed,
                chain: seedData.chain,
                cryptoType: seedData.chain.isEthereumBased ? nil : seedData.cryptoType,
                derivationPath: seedData.derivationPath,
                data: seedData.seed.toHex(includePrefix: true),
                ethereumBased: seedData.chain.isEthereumBased
            )
        }

        valueForBackup = viewModels.map { $0.data }

        let multipleExportViewModel = MultiExportViewModel(
            viewModels: viewModels,
            option: .seed,
            flow: flow
        )

        view?.set(viewModel: multipleExportViewModel)
        presentNotShownIfNeeded()
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
