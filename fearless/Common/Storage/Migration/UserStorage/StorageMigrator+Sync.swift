import Foundation

// TODO: Move this logic to app loading state
extension UserStorageMigrator: Migrating {
    func migrate() throws {
        let migrationPerformed = try performMigration()

        if migrationPerformed {
            Logger.shared.info("Db migration completed")
        }
    }
}
