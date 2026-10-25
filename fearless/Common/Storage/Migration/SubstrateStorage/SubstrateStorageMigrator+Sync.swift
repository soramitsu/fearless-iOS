import Foundation

extension SubstrateStorageMigrator: Migrating {
    func migrate() throws {
        do {
            if let recoveryURL = try performMigrationWithRecovery() {
                Logger.shared.warning(
                    """
                    Recovered from a Substrate cache migration error by quarantining a verified \
                    cache-only store at \(recoveryURL.path)
                    """
                )
            }
            clearReportedRetry()
        } catch let migrationError as SubstrateStorageMigrationError {
            // Retry first: startup offers Retry for a failure that can pass, such as a
            // mapping step that ran out of memory, before saved contacts, custom nodes and
            // TON Connect sessions are set aside with the store.
            if reportsForRetryBeforeSetAside(migrationError) {
                throw migrationError
            }
            try continueWithFreshStore(after: migrationError)
        } catch let replacementError as CrashConsistentStoreReplacementError {
            try continueWithFreshStore(after: replacementError)
        }

        Logger.shared.info("Substrate DB migration check completed")
    }

    /// A network-data store this build cannot use never stops the app from
    /// opening: it is kept whole in the retained archive and the Core Data
    /// stack creates a fresh store.
    private func continueWithFreshStore(after failure: Error) throws {
        let retainedURL = try setAsideUnusableStore(after: failure)
        clearReportedRetry()

        Logger.shared.warning(
            """
            Substrate store could not be used (\(failure.localizedDescription)). It is kept \
            unchanged at \(retainedURL.path); continuing with a fresh store
            """
        )
    }
}
