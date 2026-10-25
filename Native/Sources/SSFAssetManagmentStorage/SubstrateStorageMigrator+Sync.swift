import Foundation

protocol Migrating {
    func migrate() throws
}

extension SubstrateStorageMigrator: Migrating {
    func migrate() throws {
        guard requiresMigration() else {
            return
        }

        performMigration()
    }
}
