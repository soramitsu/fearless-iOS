import UIKit
import SoraFoundation

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol!
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func load() {}
    func select(language: NodeSelectionItem) {}
}
