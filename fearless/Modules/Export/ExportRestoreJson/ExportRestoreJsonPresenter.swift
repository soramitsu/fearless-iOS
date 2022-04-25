import Foundation

final class ExportRestoreJsonPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportRestoreJsonWireframeProtocol!

    let model: RestoreJson

    init(model: RestoreJson) {
        self.model = model
    }
}

extension ExportRestoreJsonPresenter: ExportGenericPresenterProtocol {
    func setup() {
        let viewModel = ExportStringViewModel(
            option: .keystore,
            chain: model.chain,
            cryptoType: model.cryptoType,
            derivationPath: nil,
            data: model.data
        )
        view?.set(viewModel: viewModel)
    }

    func activateExport() {
        let items: [JsonExportAction] = [.file, .text]
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self else { return }
            let action = items[selectedIndex]
            switch action {
            case .file:
                self.wireframe.share(
                    sources: [self.model.fileURL],
                    from: self.view
                ) { [weak self] completed in
                    if completed {
                        self?.wireframe.close(view: self?.view)
                    }
                }
            case .text:
                self.wireframe.share(
                    sources: [self.model.data],
                    from: self.view
                ) { [weak self] completed in
                    if completed {
                        self?.wireframe.close(view: self?.view)
                    }
                }
            default:
                break
            }
        }

        wireframe.presentExportActionsFlow(
            from: view,
            items: items,
            callback: selectionCallback
        )
    }

    func activateAccessoryOption() {
        wireframe.showChangePassword(from: view)
    }
}
