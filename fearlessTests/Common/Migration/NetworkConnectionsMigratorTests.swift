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

    func testOnFinalityMigration() {
        guard
            let deprecatedOnFinalityConnection = ConnectionItem
                .deprecatedConnections
                .first(where: { $0.title.contains("OnFinality")} )
        else {
            XCTFail("Unexpected OnFinality connection")
            return
        }
        var settings = InMemorySettingsManager()

        // given
        settings.selectedConnection = deprecatedOnFinalityConnection
        let migrator = NetworkConnectionsMigrator(settings: settings)

        // when
        do {
            try migrator.migrate()
        } catch {
            XCTFail(error.localizedDescription)
        }

        // then
        let сonnectionAfterMigration = settings.selectedConnection
        XCTAssert(сonnectionAfterMigration.title.contains("OnFinality"))
        XCTAssert(сonnectionAfterMigration != deprecatedOnFinalityConnection)
    }
}
