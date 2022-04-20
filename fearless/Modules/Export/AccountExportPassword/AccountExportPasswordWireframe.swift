import Foundation

final class AccountExportPasswordWireframe: AccountExportPasswordWireframeProtocol {
    func showJSONExport(_ jsons: [RestoreJson], from view: AccountExportPasswordViewProtocol?) {
        guard let exportView = ExportRestoreJsonViewFactory.createView(with: jsons) else {
            return
        }

        view?.controller.navigationController?.pushViewController(exportView.controller, animated: true)
    }

    func back(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
