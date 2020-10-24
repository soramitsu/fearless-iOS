import Foundation

final class AddConnectionWireframe: AddConnectionWireframeProtocol {
    func close(view: AddConnectionViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
