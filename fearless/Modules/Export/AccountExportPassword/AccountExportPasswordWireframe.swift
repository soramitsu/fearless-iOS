import Foundation

final class AccountExportPasswordWireframe: AccountExportPasswordWireframeProtocol {
    func showJSONExport(_ json: RestoreJson, from view: AccountExportPasswordViewProtocol?) {
        guard let exportView = ExportRestoreJsonViewFactory.createView(with: json) else {
            return
        }

        view?.controller.navigationController?.pushViewController(exportView.controller, animated: true)
    }
}
