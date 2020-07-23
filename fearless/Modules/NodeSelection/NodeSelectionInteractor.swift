import UIKit
import SoraFoundation
import SoraKeystore

final class NodeSelectionInteractor {
    weak var presenter: NodeSelectionInteractorOutputProtocol!

    let applicationConfig: ApplicationConfigProtocol
    let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol, applicationConfig: ApplicationConfigProtocol) {
        self.settings = settings
        self.applicationConfig = applicationConfig
    }
}

extension NodeSelectionInteractor: NodeSelectionInteractorInputProtocol {
    func load() {
        let selectedConnection = settings.selectedConnection

        presenter?.didLoad(nodeItems: [selectedConnection])

        presenter?.didLoad(selectedNodeItem: selectedConnection)
    }

    func select(nodeItem: ConnectionItem) {}
}
