import Foundation
import SoraFoundation

protocol ExportRestoreJsonInteractorProtocol: AnyObject {
    func walletDidBackuped(completion: @escaping (Result<Void, Error>) -> Void)
}

final class ExportRestoreJsonPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportRestoreJsonWireframeProtocol!
    var interacror: ExportRestoreJsonInteractorProtocol!

    let localizationManager: LocalizationManager
    let models: [RestoreJson]
    let flow: ExportFlow

    private var sharedFiles: Set<URL> = []
    private var backupRecorded = false
    private var backupPending = false
    private var backupAttempt: UUID?
    private var isLeaving = false

    init(
        models: [RestoreJson],
        flow: ExportFlow,
        localizationManager: LocalizationManager
    ) {
        self.models = models
        self.flow = flow
        self.localizationManager = localizationManager
    }

    private func activateExport(models: [RestoreJson]) {
        guard !isLeaving, !backupPending else { return }
        let items: [JsonExportAction] = [.file, .text]
        var selectionHandled = false
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self, !self.isLeaving, !self.backupPending,
                  !selectionHandled, items.indices.contains(selectedIndex) else { return }
            selectionHandled = true
            var shareHandled = false
            let handler: SharingCompletionHandler = { [weak self] completed in
                guard !shareHandled else { return }
                shareHandled = true
                guard completed else { return }
                self?.checkBackupStatus(shared: models)
            }
            let action = items[selectedIndex]
            switch action {
            case .file:
                self.wireframe.share(sources: models.map(\.fileURL), from: self.view, with: handler)
            case .text:
                self.wireframe.share(sources: models.map(\.data), from: self.view, with: handler)
            }
        }

        wireframe.presentExportActionsFlow(
            from: view,
            items: items,
            callback: selectionCallback
        )
    }

    private func checkBackupStatus(shared: [RestoreJson]) {
        sharedFiles.formUnion(shared.map(\.fileURL))
        guard !isLeaving, !backupPending, !backupRecorded, case .multiple = flow, !models.isEmpty,
              models.allSatisfy({ sharedFiles.contains($0.fileURL) }) else {
            return
        }

        // Every requested account must have exactly one produced model. A partial
        // recovery export or a single-account export never backs up the whole wallet.
        var remaining = models
        for requested in flow.exportingAccounts {
            guard let index = remaining.firstIndex(where: {
                $0.chain.chainId == requested.chain.chainId && $0.accountId == requested.account.accountId
            }) else {
                return
            }
            remaining.remove(at: index)
        }
        guard remaining.isEmpty else { return }
        recordBackupStatus()
    }

    private func recordBackupStatus() {
        guard !isLeaving, !backupPending, !backupRecorded else { return }
        backupPending = true
        let attempt = UUID()
        backupAttempt = attempt
        interacror.walletDidBackuped { [weak self] result in
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
}

extension ExportRestoreJsonPresenter: ExportGenericPresenterProtocol {
    func didLoadView() {}

    func didLeaveView() {
        isLeaving = true
    }

    func setup() {
        let viewModels = models.compactMap { model in
            ExportStringViewModel(
                option: .keystore,
                chain: model.chain,
                cryptoType: model.cryptoType,
                derivationPath: nil,
                data: model.data,
                ethereumBased: model.chain.isEthereumBased
            )
        }

        let multipleExportViewModel = MultiExportViewModel(
            viewModels: viewModels,
            option: .keystore,
            flow: flow
        )

        view?.set(viewModel: multipleExportViewModel)
    }

    func didTapExportEthereumButton() {
        let selected = models.filter { $0.chain.isEthereumBased }
        if !selected.isEmpty {
            activateExport(models: selected)
        }
    }

    func didTapExportSubstrateButton() {
        let selected = models.filter { !$0.chain.isEthereumBased }
        if !selected.isEmpty {
            activateExport(models: selected)
        }
    }

    func activateAccessoryOption() {
        guard !isLeaving, !backupPending else { return }
        wireframe.showChangePassword(from: view)
    }
}
