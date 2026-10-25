import Foundation
import IrohaCrypto
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit

final class ExportMnemonicPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportMnemonicWireframeProtocol!
    var interactor: ExportMnemonicInteractorInputProtocol!

    let flow: ExportFlow
    let localizationManager: LocalizationManager

    private(set) var exportDatas: [ExportMnemonicData]?
    private var isLeaving = false
    private var isWarningOpen = false
    private var warningPresented = false
    private var notShown: [ExportMnemonicNotShown] = []
    private var notShownNoticePresented = false

    init(flow: ExportFlow, localizationManager: LocalizationManager) {
        self.flow = flow
        self.localizationManager = localizationManager
    }
}

extension ExportMnemonicPresenter: ExportGenericPresenterProtocol {
    func didLoadView() {
        guard !isLeaving, !warningPresented else { return }
        warningPresented = true
        isWarningOpen = true
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

        wireframe.present(viewModel: viewModel, from: view)
    }

    func didLeaveView() {
        isLeaving = true
        exportDatas = nil
        interactor.cancelExport()
    }

    func setup() {
        // Hold recovery notices until the attached initial warning has closed.
        isWarningOpen = true
        guard !isLeaving else { return }
        switch flow {
        case let .single(chain, address, wallet):
            interactor.fetchExportDataForAddress(address, chain: chain, wallet: wallet)
        case let .multiple(wallet, _):
            interactor.fetchExportDataForWallet(wallet: wallet, accounts: flow.exportingAccounts)
        }
    }

    func activateExport() {
        guard !isLeaving, let exportData = exportDatas?.first else {
            return
        }

        let proof: VerifiedMnemonicBackup?
        if case .multiple = flow {
            proof = exportData.backupProof
        } else {
            proof = nil
        }
        wireframe.openConfirmationForMnemonic(exportData.mnemonic, wallet: flow.wallet, backupProof: proof, from: view)
    }

    func activateAccessoryOption() {}
}

extension ExportMnemonicPresenter: ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportDatas: [ExportMnemonicData]) {
        didReceive(exportDatas: exportDatas, notShown: [])
    }

    func didReceive(exportDatas: [ExportMnemonicData], notShown: [ExportMnemonicNotShown]) {
        guard !isLeaving else { return }
        self.exportDatas = exportDatas
        self.notShown = notShown

        let viewModels = exportDatas.compactMap { exportData in
            ExportMnemonicViewModel(
                option: .mnemonic,
                chain: exportData.chain,
                cryptoType: exportData.cryptoType,
                derivationPath: exportData.derivationPath,
                mnemonic: exportData.mnemonic.allWords(),
                ethereumBased: exportData.chain.isEthereumBased,
                exactPhrase: exactPhraseForPresentation(exportData.mnemonic)
            )
        }

        let multipleExportViewModel = MultiExportViewModel(
            viewModels: viewModels,
            option: .mnemonic,
            flow: flow
        )
        view?.set(viewModel: multipleExportViewModel)
        presentNotShownIfNeeded()
    }

    func didReceive(error: Error) {
        guard !isLeaving else { return }
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}

private extension ExportMnemonicPresenter {
    func exactPhraseForPresentation(_ mnemonic: IRMnemonicProtocol) -> String? {
        guard let native = mnemonic as? LegacyTonMnemonic else { return nil }
        let phrase = native.toString()
        let normalized = phrase.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
        return phrase == normalized ? nil : phrase
    }

    func warningDidClose() {
        isWarningOpen = false
        presentNotShownIfNeeded()
    }

    func presentNotShownIfNeeded() {
        guard !isLeaving, !isWarningOpen, !notShownNoticePresented, !notShown.isEmpty else { return }
        notShownNoticePresented = true
        let languages = localizationManager.selectedLocale.rLanguages
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.backupWalletJson(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText,
            handlerAfterDismissal: true
        ) { [weak self] in
            guard let self, !self.isLeaving else { return }
            self.wireframe.showJsonExport(flow: self.flow, from: self.view)
        }
        // Released native TON wallets have no JSON export route. A rejected native
        // phrase must not advertise an unsupported backup method.
        let canExportJson = flow.wallet.legacyTonAccount == nil || notShown
            .contains { !$0.chain.isTonCompatibilityChain }
        let message = canExportJson
            ? R.string.localizable.exportMnemonicPartialMessage(
                notShown.map(\.chain.name).joined(separator: "\n"),
                preferredLanguages: languages
            )
            : R.string.localizable.universalRecoveryMismatchMessage(preferredLanguages: languages)
        let model = SheetAlertPresentableViewModel(
            title: R.string.localizable.exportMnemonicUnavailableTitle(preferredLanguages: languages),
            message: message,
            actions: canExportJson ? [action] : [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )
        wireframe.present(viewModel: model, from: view)
    }
}

extension ExportMnemonicPresenter: ExactMnemonicExportCopying {
    func copyExactMnemonic(_ phrase: String) -> Bool {
        guard !isLeaving, !isWarningOpen,
              UIApplication.shared.applicationState == .active,
              let controller = view?.controller, controller.viewIfLoaded?.window != nil,
              !controller.isBeingDismissed, !controller.isMovingFromParent,
              controller.presentedViewController == nil, controller.transitionCoordinator == nil,
              controller.navigationController?.isBeingDismissed != true,
              controller.navigationController?.transitionCoordinator == nil,
              controller.navigationController.map({ $0.topViewController === controller }) ?? true,
              exportDatas?.contains(where: { exactPhraseForPresentation($0.mnemonic) == phrase }) == true
        else { return false }
        UIPasteboard.general.setItems([["public.utf8-plain-text": phrase]], options: [
            .localOnly: true,
            .expirationDate: Date(timeIntervalSinceNow: 60)
        ])
        return true
    }
}
