import Foundation
import SoraFoundation

protocol ExportRestoreJsonInteractorProtocol: AnyObject {
    func walletDidBackuped()
}

final class ExportRestoreJsonPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportRestoreJsonWireframeProtocol!
    var interacror: ExportRestoreJsonInteractorProtocol!

    let localizationManager: LocalizationManager
    let models: [RestoreJson]
    let flow: ExportFlow

    private enum BackupType {
        case substrate
        case ethereum
    }

    private var substrateIsBackuped = false
    private var ethereumIsBackuped = false

    init(
        models: [RestoreJson],
        flow: ExportFlow,
        localizationManager: LocalizationManager
    ) {
        self.models = models
        self.flow = flow
        self.localizationManager = localizationManager
    }

    private func activateExport(model: RestoreJson, type: BackupType) {
        let items: [JsonExportAction] = [.file, .text]
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self else { return }

            let handler: SharingCompletionHandler = { [weak self] completed in
                guard completed else {
                    return
                }
                self?.checkBackupStatus(type: type)
            }
            let action = items[selectedIndex]
            switch action {
            case .file:
                self.wireframe.share(sources: [model.fileURL], from: self.view, with: handler)
            case .text:
                self.wireframe.share(sources: [model.data], from: self.view, with: handler)
            }
        }

        wireframe.presentExportActionsFlow(
            from: view,
            items: items,
            callback: selectionCallback
        )
    }

    private func checkBackupStatus(type: ExportRestoreJsonPresenter.BackupType) {
        switch type {
        case .substrate:
            substrateIsBackuped = true
        case .ethereum:
            ethereumIsBackuped = true
        }
        guard substrateIsBackuped, ethereumIsBackuped else {
            return
        }
        interacror.walletDidBackuped()
    }
}

extension ExportRestoreJsonPresenter: ExportGenericPresenterProtocol {
    func didLoadView() {}

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
        if let model = models.first(where: { $0.chain.isEthereumBased }) {
            activateExport(model: model, type: .ethereum)
        }
    }

    func didTapExportSubstrateButton() {
        if let model = models.first(where: { !$0.chain.isEthereumBased }) {
            activateExport(model: model, type: .substrate)
        }
    }

    func activateAccessoryOption() {
        wireframe.showChangePassword(from: view)
    }
}
