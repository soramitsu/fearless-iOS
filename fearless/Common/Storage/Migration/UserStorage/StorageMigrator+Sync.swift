import Foundation

// TODO: Move this logic to app loading state
extension UserStorageMigrator: Migrating {
    func migrate() throws {
        guard requiresMigration() else {
            return
        }

        performMigration()

        Logger.shared.info("Db migration completed")
    }
}
