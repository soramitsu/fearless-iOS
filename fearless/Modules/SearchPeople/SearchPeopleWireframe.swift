import Foundation

final class SearchPeopleWireframe: SearchPeopleWireframeProtocol {
    func close(_ view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
