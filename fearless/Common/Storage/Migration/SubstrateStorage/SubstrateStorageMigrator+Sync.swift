import Foundation

extension SubstrateStorageMigrator: Migrating {
    func migrate() throws {
        guard requiresMigration() else {
            return
        }

        performMigration()

        Logger.shared.info("Db migration completed")
    }
}
