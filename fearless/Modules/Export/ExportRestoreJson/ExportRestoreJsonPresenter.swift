import Foundation

final class ExportRestoreJsonPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportRestoreJsonWireframeProtocol!

    let models: [RestoreJson]

    init(models: [RestoreJson]) {
        self.models = models
    }

    private func activateExport(model: RestoreJson) {
        let items: [JsonExportAction] = [.file, .text]
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self else { return }
            let action = items[selectedIndex]
            switch action {
            case .file:
                self.wireframe.share(sources: [model.fileURL], from: self.view, with: nil)
            case .text:
                self.wireframe.share(sources: [model.data], from: self.view, with: nil)
            }
        }

        wireframe.presentExportActionsFlow(
            from: view,
            items: items,
            callback: selectionCallback
        )
    }
}

extension ExportRestoreJsonPresenter: ExportGenericPresenterProtocol {
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

        let multipleExportViewModel = MultiExportViewModel(viewModels: viewModels)

        view?.set(viewModel: multipleExportViewModel)
    }

    func activateExport() {}

    func didTapExportEthereumButton() {
        if let model = models.first(where: { $0.chain.isEthereumBased }) {
            activateExport(model: model)
        }
    }

    func didTapExportSubstrateButton() {
        if let model = models.first(where: { !$0.chain.isEthereumBased }) {
            activateExport(model: model)
        }
    }

    func activateAccessoryOption() {
        wireframe.showChangePassword(from: view)
    }
}
