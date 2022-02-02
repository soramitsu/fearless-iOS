import UIKit

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol?

    let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(chain: chain)
    }
}
