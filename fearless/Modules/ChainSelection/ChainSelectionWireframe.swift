import Foundation

final class ChainSelectionWireframe: ChainSelectionWireframeProtocol {
    weak var delegate: ChainSelectionDelegate?

    func complete(on view: ChainSelectionViewProtocol, selecting chain: ChainModel?) {
        if view.controller.navigationController?.viewControllers.count == 1 {
            view.controller.dismiss(animated: true, completion: nil)
        } else {
            view.controller.navigationController?.popViewController(animated: true)
        }

        delegate?.chainSelection(view: view, didCompleteWith: chain)
    }
}
