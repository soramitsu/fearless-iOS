import Foundation

final class ExportRestoreJsonWireframe: ExportRestoreJsonWireframeProtocol {
    func showChangePassword(from view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func presentExportActionsFlow(
        from view: ControllerBackedProtocol?,
        items: [JsonExportAction],
        callback: @escaping ModalPickerSelectionCallback
    ) {
        let actionsView = ModalPickerFactory.createPickerForList(
            items,
            callback: callback,
            context: nil
        )

        guard let actionsView = actionsView else {
            return
        }

        view?.controller.navigationController?.present(actionsView, animated: true)
    }

    func back(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
