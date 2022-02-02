import Foundation

protocol NodeSelectionViewModelFactoryProtocol {
    func buildViewModel(from chain: ChainModel) -> NodeSelectionViewModel
}

class NodeSelectionViewModelFactory: NodeSelectionViewModelFactoryProtocol {
    func buildViewModel(from chain: ChainModel) -> NodeSelectionViewModel {
        NodeSelectionViewModel(
            title: chain.name,
            autoSelectEnabled: false,
            nodes: Array(chain.nodes)
        )
    }
}
