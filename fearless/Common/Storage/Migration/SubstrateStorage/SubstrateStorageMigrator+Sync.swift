import Foundation

extension SubstrateStorageMigrator: Migrating {
    func migrate() throws {
        let recoveryURL = try performMigrationWithRecovery()

        if let recoveryURL {
            Logger.shared.warning(
                """
                Recovered from a Substrate cache migration error by quarantining a verified \
                cache-only store at \(recoveryURL.path)
                """
            )
        }

        Logger.shared.info("Substrate DB migration check completed")
    }
}
