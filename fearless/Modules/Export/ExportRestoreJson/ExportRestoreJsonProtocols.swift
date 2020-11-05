import Foundation

protocol ExportRestoreJsonWireframeProtocol: SharingPresentable {
    func showChangePassword(from view: ExportGenericViewProtocol?)
}

protocol ExportRestoreJsonViewFactoryProtocol {
    static func createView(with model: RestoreJson) -> ExportGenericViewProtocol?
}
