import Foundation

final class ChainSelectionWireframe: ChainSelectionWireframeProtocol {
    weak var delegate: ChainSelectionDelegate?

    func complete(on view: ChainSelectionViewProtocol, selecting chain: ChainModel) {
        view.controller.dismiss(animated: true, completion: nil)

        delegate?.chainSelection(view: view, didCompleteWith: chain)
    }
}
