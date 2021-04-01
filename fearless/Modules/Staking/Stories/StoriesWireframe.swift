import Foundation

final class StoriesWireframe: StoriesWireframeProtocol {
    func close(view: StoriesViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
