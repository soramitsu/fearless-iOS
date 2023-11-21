import Foundation

final class NftFiltersRouter: NftFiltersRouterProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
