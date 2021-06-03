import Foundation

final class KaruraCrowdloanWireframe: KaruraCrowdloanWireframeProtocol {
    func complete(on view: KaruraCrowdloanViewProtocol?) {
        view?.controller.dismiss(animated: true, completion: nil)
    }
}
