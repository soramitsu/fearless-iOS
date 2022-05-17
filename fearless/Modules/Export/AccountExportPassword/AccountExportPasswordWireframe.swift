import Foundation

final class AccountExportPasswordWireframe: AccountExportPasswordWireframeProtocol {
    func showJSONExport(
        _ jsons: [RestoreJson],
        flow: ExportFlow,
        from view: AccountExportPasswordViewProtocol?
    ) {
        guard let exportView = ExportRestoreJsonViewFactory.createView(with: jsons, flow: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(exportView.controller, animated: true)
    }

    func back(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
