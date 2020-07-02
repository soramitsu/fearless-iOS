import UIKit
import SoraFoundation

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol!

    let applicationConfig: ApplicationConfigProtocol

    init(applicationConfig: ApplicationConfigProtocol) {
        self.applicationConfig = applicationConfig
    }
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func load() {
        presenter?.didLoad(nodeItems: applicationConfig.nodes)

        if let node = applicationConfig.nodes.first {
            presenter?.didLoad(selectedNodeItem: node)
        }
    }

    func select(nodeItem: NodeSelectionItem) {}
}
