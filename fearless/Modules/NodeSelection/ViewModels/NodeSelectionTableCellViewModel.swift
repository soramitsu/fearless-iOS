import Foundation
import SSFModels

protocol NodeSelectionTableCellViewModelDelegate: AnyObject {
    func deleteNode(_ node: ChainNodeModel)
    func showDefaultNodeInfo(_ node: ChainNodeModel)
    func showCustomNodeInfo(_ node: ChainNodeModel)
}

class NodeSelectionTableCellViewModel {
    let node: ChainNodeModel
    let selected: Bool
    let selectable: Bool
    let editable: Bool
    weak var delegate: NodeSelectionTableCellViewModelDelegate?

    init(
        node: ChainNodeModel,
        selected: Bool,
        selectable: Bool,
        editable: Bool,
        delegate: NodeSelectionTableCellViewModelDelegate?
    ) {
        self.node = node
        self.selected = selected
        self.selectable = selectable
        self.editable = editable
        self.delegate = delegate
    }
}

extension NodeSelectionTableCellViewModel: NodeSelectionTableCellDelegate {
    func didTapDeleteButton() {
        delegate?.deleteNode(node)
    }

    func didTapInfoButton() {
        if editable {
            delegate?.showCustomNodeInfo(node)
        } else {
            delegate?.showDefaultNodeInfo(node)
        }
    }
}
