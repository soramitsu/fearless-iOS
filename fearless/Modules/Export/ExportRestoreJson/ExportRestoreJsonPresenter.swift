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
        let viewModel = ExportStringViewModel(option: .keystore,
                                              networkType: model.chain,
                                              derivationPath: nil,
                                              cryptoType: model.cryptoType,
                                              data: model.data)
        view?.set(viewModel: viewModel)
    }

    func activateExport() {
        wireframe.share(source: TextSharingSource(message: model.data),
                        from: view) { [weak self] (completed) in
            if completed {
                self?.wireframe.close(view: self?.view)
            }
        }
    }

    func activateAccessoryOption() {
        wireframe.showChangePassword(from: view)
    }
}
