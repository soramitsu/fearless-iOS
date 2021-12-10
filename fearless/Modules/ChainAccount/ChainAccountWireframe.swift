import Foundation

final class ChainAccountWireframe: ChainAccountWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
