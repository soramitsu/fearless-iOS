import Foundation

protocol ExportRestoreJsonWireframeProtocol: SharingPresentable {
    func close(view: ExportGenericViewProtocol?)
    func showChangePassword(from view: ExportGenericViewProtocol?)
}

protocol ExportRestoreJsonViewFactoryProtocol {
    static func createView(with model: RestoreJson) -> ExportGenericViewProtocol?
}
