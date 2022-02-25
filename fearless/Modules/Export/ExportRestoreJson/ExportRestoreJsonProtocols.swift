import Foundation

protocol ExportRestoreJsonWireframeProtocol: ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?)
    func showChangePassword(from view: ExportGenericViewProtocol?)
    func presentExportActionsFlow(
        from view: ControllerBackedProtocol?,
        items: [JsonExportAction],
        callback: @escaping ModalPickerSelectionCallback
    )
}

protocol ExportRestoreJsonViewFactoryProtocol {
    static func createView(with model: RestoreJson) -> ExportGenericViewProtocol?
}
