import Foundation

final class ExportRestoreJsonPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportRestoreJsonWireframeProtocol!

    let models: [RestoreJson]

    init(models: [RestoreJson]) {
        self.models = models
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
                data: model.data
            )
        }

        let multipleExportViewModel = MultiExportViewModel(viewModels: viewModels)

        view?.set(viewModel: multipleExportViewModel)
    }

    func activateExport() {
//        let items: [JsonExportAction] = [.file, .text]
//        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
//            guard let self = self else { return }
//            let action = items[selectedIndex]
//            switch action {
//            case .file:
//                self.wireframe.share(
//                    sources: [self.model.fileURL],
//                    from: self.view
//                ) { [weak self] completed in
//                    if completed {
//                        self?.wireframe.close(view: self?.view)
//                    }
//                }
//            case .text:
//                self.wireframe.share(
//                    sources: [self.model.data],
//                    from: self.view
//                ) { [weak self] completed in
//                    if completed {
//                        self?.wireframe.close(view: self?.view)
//                    }
//                }
//            default:
//                break
//            }
//        }
//
//        wireframe.presentExportActionsFlow(
//            from: view,
//            items: items,
//            callback: selectionCallback
//        )
    }

    func didTapExportEthereumButton() {}

    func didTapExportSubstrateButton() {}

    func activateAccessoryOption() {
        wireframe.showChangePassword(from: view)
    }
}
