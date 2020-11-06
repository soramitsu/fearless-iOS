import Foundation

final class ExportRestoreJsonWireframe: ExportRestoreJsonWireframeProtocol {
    func showChangePassword(from view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
