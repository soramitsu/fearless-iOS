import Foundation

final class NetworkInfoWireframe: NetworkInfoWireframeProtocol {
    func close(view: NetworkInfoViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
