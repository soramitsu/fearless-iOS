import SoraKeystore

final class NetworkConnectionsMigrator: Migrating {
    private(set) var settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }

    func migrate() throws {
        let selectedConnection = settings.selectedConnection
        if ConnectionItem.deprecatedConnections.contains(selectedConnection) {
            settings.selectedConnection = .defaultConnection
        }
    }
}
