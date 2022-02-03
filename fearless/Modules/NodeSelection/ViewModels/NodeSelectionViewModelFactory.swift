import Foundation

protocol NodeSelectionViewModelFactoryProtocol {
    func buildViewModel(from chain: ChainModel) -> NodeSelectionViewModel
}

class NodeSelectionViewModelFactory: NodeSelectionViewModelFactoryProtocol {
    func buildViewModel(from chain: ChainModel) -> NodeSelectionViewModel {
        let cellViewModels: [NodeSelectionTableCellViewModel] = chain.nodes.compactMap { node in
            NodeSelectionTableCellViewModel(
                node: node,
                selected: node.url == chain.selectedNode?.url,
                selectable: chain.selectedNode != nil
            )
        }
        return NodeSelectionViewModel(
            title: chain.name,
            autoSelectEnabled: chain.selectedNode == nil,
            viewModels: cellViewModels
        )
    }
}
