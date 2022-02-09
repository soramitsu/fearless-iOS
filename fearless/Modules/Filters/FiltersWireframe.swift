import Foundation

final class FiltersWireframe: FiltersWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
