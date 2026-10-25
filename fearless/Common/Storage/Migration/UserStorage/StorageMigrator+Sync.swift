import Foundation

// RootInteractor runs this synchronous adapter on its single-worker migration
// queue. Successful return opens the startup barrier for storage preflight.
extension UserStorageMigrator: Migrating {
    func migrate() throws {
        let migrationPerformed = try performMigration()

        if migrationPerformed {
            Logger.shared.info("Db migration completed")
        }
    }
}
