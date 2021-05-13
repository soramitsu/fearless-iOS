import XCTest
import SoraKeystore
@testable import fearless

final class NetworkConnectionsMigratorTests: XCTestCase {

    func testMigration() {
        var settings = InMemorySettingsManager()
        settings.selectedConnection = ConnectionItem.deprecatedConnections[0]
        let migrator = NetworkConnectionsMigrator(settings: settings)

        do {
            try migrator.migrate()
        } catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssert(settings.selectedConnection == .defaultConnection)
    }
}
