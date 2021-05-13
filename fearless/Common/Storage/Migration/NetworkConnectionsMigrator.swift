import SoraKeystore

final class NetworkConnectionsMigrator: Migrating {
    private(set) var settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }

    func migrate() throws {
        let selectedConnection = settings.selectedConnection
        let deprecatedConnections = ConnectionItem.deprecatedConnections
        let supportedConnections = ConnectionItem.supportedConnections

        if deprecatedConnections.contains(selectedConnection) {
            let suitableConnection = supportedConnections.first(where: { $0.type == selectedConnection.type })
            settings.selectedConnection = suitableConnection ?? .defaultConnection
        }
    }
}
