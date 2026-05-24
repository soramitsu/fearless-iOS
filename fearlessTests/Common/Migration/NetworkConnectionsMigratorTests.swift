import XCTest
import FearlessSecureStorage
@testable import fearless

final class NetworkConnectionsMigratorTests: XCTestCase {
    func testFinalize_whenSelectedConnectionRemoved_thenClearsOnlyLegacyConnectionSetting() throws {
        let settings = InMemorySettingsManager()
        let legacyConnectionData = Data([0x01, 0x02, 0x03])
        let unrelatedKey = "unrelated.setting"

        settings.set(value: legacyConnectionData, for: SettingsKey.selectedConnection.rawValue)
        settings.set(value: "keep", for: unrelatedKey)

        let migrator = SettingsMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            settings: settings
        )

        try migrator.switchVersion()
        migrator.remove(key: SettingsKey.selectedConnection.rawValue)

        XCTAssertEqual(settings.data(for: SettingsKey.selectedConnection.rawValue), legacyConnectionData)

        try migrator.finalize()

        XCTAssertNil(settings.data(for: SettingsKey.selectedConnection.rawValue))
        XCTAssertEqual(settings.string(for: unrelatedKey), "keep")
    }

    func testFinalize_whenSelectedAccountAndConnectionRemoved_thenClearsBothLegacySelections() throws {
        let settings = InMemorySettingsManager()
        settings.set(value: Data([0x0A]), for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: Data([0x0B]), for: SettingsKey.selectedConnection.rawValue)

        let migrator = SettingsMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            settings: settings
        )

        try migrator.switchVersion()
        migrator.remove(key: SettingsKey.selectedAccount.rawValue)
        migrator.remove(key: SettingsKey.selectedConnection.rawValue)

        try migrator.finalize()

        XCTAssertNil(settings.data(for: SettingsKey.selectedAccount.rawValue))
        XCTAssertNil(settings.data(for: SettingsKey.selectedConnection.rawValue))
    }
}
