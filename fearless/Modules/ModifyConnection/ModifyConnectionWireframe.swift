import Foundation

final class ModifyConnectionWireframe: ModifyConnectionWireframeProtocol {
    func close(view: ModifyConnectionViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
