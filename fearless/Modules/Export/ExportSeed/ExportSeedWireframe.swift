import Foundation

final class ExportSeedWireframe: ExportSeedWireframeProtocol {
    func back(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
