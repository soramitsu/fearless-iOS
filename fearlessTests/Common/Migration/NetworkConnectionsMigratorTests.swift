import XCTest
import SoraKeystore
@testable import fearless

final class NetworkConnectionsMigratorTests: XCTestCase {

    func testMigration() {
        var settings = InMemorySettingsManager()
        settings.selectedConnection = ConnectionItem.deprecatedConnections[1]
        let migrator = NetworkConnectionsMigrator(settings: settings)

        // given
        let connectionTypeBeforeMigration = settings.selectedConnection.type

        // when
        do {
            try migrator.migrate()
        } catch {
            XCTFail(error.localizedDescription)
        }

        // then
        let connectionTypeAfterMigration = settings.selectedConnection.type
        XCTAssert(connectionTypeAfterMigration == connectionTypeBeforeMigration)
    }
}
