import Foundation

/// Startup's use of the migrator. The Substrate store holds network data and
/// local conveniences (contacts, custom nodes, TON Connect sessions), never a
/// wallet or a key, so nothing in it may keep the app from opening: startup
/// never reports a Substrate migration failure to the user.
///
/// The ladder, in order:
/// 1. Migrate (or check a current store). A failure that can pass on its own
///    is retried here, quietly, up to `startupAttemptCount` times.
/// 2. A store that is already the current model and only failed for a passing
///    reason (a private copy, free space, a file that was not accessible) stays
///    installed and opens as it is. It was checked by every earlier launch.
/// 3. A store that needs migrating while the device is out of space is left
///    untouched and startup asks for free space (INSUFFICIENT_STORAGE); the
///    migration needs room for its private copies.
/// 4. Any other store this build cannot use is moved whole into the retained
///    archive and the app starts with a fresh one. Nothing is deleted, and the
///    saved contacts are brought back from the archive by the next step.
/// 5. If even that cannot be done, the store stays untouched on disk and this
///    launch runs on an in-memory store (`SubstrateStoreStartupFallback`).
extension SubstrateStorageMigrator: Migrating {
    static let startupAttemptCount = 3

    func migrate() throws {
        removeStalePrivateCopies()

        var attempt = 0
        var lastFailure: Error?
        while attempt < Self.startupAttemptCount {
            attempt += 1
            do {
                if let recoveryURL = try performMigrationWithRecovery() {
                    Logger.shared.warning(
                        """
                        Recovered from a Substrate cache migration error by quarantining a verified \
                        cache-only store at \(recoveryURL.path)
                        """
                    )
                }
                Logger.shared.info("Substrate DB migration check completed")
                return
            } catch {
                if Self.isSimulatedProcessDeath(error) {
                    throw error
                }

                lastFailure = error
                Logger.shared.warning(
                    "Substrate store check attempt \(attempt) failed: \(Self.failureKind(of: error))"
                )

                guard
                    attempt < Self.startupAttemptCount,
                    Self.isWorthRetrying(error)
                else {
                    break
                }

                Thread.sleep(forTimeInterval: Self.retryDelay(afterAttempt: attempt))
            }
        }

        guard let lastFailure else {
            return
        }

        try resolveWithoutBlockingStartup(after: lastFailure)
    }

    // MARK: Private

    private static func retryDelay(afterAttempt attempt: Int) -> TimeInterval {
        #if DEBUG
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                return 0
            }
        #endif
        return attempt == 1 ? 0.25 : 1
    }

    /// A failure that the same store can pass on another attempt, such as a
    /// mapping step that ran out of memory. No bundled model reading the store,
    /// a stuck transaction or the device itself are not helped by retrying.
    private static func isWorthRetrying(_ error: Error) -> Bool {
        if let migrationError = error as? SubstrateStorageMigrationError {
            return migrationError.isRetriedBeforeStoreSetAside
        }

        return !isEnvironmentFailure(error)
    }

    private func resolveWithoutBlockingStartup(after failure: Error) throws {
        let failureKind = Self.failureKind(of: failure)

        // A build without its own current model cannot open any store, fresh
        // or in memory. Tests pin every bundled model; this stays loud.
        if
            let migrationError = failure as? SubstrateStorageMigrationError,
            case let .modelUnavailable(version) = migrationError,
            version == targetVersion {
            throw failure
        }

        let detectedVersion = takeDetectedVersion()
        let isCurrentStore = detectedVersion.map { $0 == targetVersion }
            ?? installedStoreIsTargetVersion()

        if isCurrentStore, Self.isPassingFailureForCurrentStore(failure) {
            Logger.shared.warning(
                "Substrate store is current; opening it as it is after \(failureKind)"
            )
            return
        }

        if Self.isOutOfSpaceFailure(failure) {
            // Only a store that still needs migrating gets here.
            throw insufficientStorageFailure(after: failure)
        }

        do {
            let retainedURL = try setAsideUnusableStore(after: failure)
            Logger.shared.warning(
                """
                Substrate store could not be used (\(failureKind)). It is kept unchanged at \
                \(retainedURL.path); continuing with a fresh store
                """
            )
        } catch {
            if Self.isSimulatedProcessDeath(error) {
                throw error
            }

            SubstrateStoreStartupFallback.activateInMemoryStore(
                reason: "\(failureKind); set-aside: \(Self.failureKind(of: error))"
            )
        }
    }

    /// A current store keeps opening as it is when the failure says nothing
    /// about its contents: the check could not make or finish its private
    /// copy, or the device was out of space or locked. A failure while reading
    /// or repairing rows (an Objective-C exception included) could recur once
    /// the app reads them, so that store is set aside instead.
    private static func isPassingFailureForCurrentStore(_ error: Error) -> Bool {
        if isEnvironmentFailure(error) {
            return true
        }

        guard let migrationError = error as? SubstrateStorageMigrationError else {
            return false
        }

        switch migrationError {
        case .sourceSnapshotFailed,
             .walCheckpointFailed,
             .temporaryDirectoryCreationFailed,
             .temporaryStoreCleanupFailed,
             .pendingCacheRecoveryFailed,
             .pendingStoreSetAsideFailed,
             .storeSetAsideFailed:
            return true
        case .objectiveCException,
             .storeReplacementFailed,
             .metadataUnreadable,
             .unknownStoreVersion,
             .ambiguousStoreVersion,
             .modelUnavailable,
             .migrationPathUnavailable,
             .mappingUnavailable,
             .transformableSanitizationFailed,
             .unsupportedTransformableAttribute,
             .migrationStepFailed,
             .sourceStoreInspectionFailed,
             .protectedDataInspectionRejected,
             .stagedStoreMetadataUnreadable,
             .stagedStoreInvalid,
             .stagedStoreInspectionFailed,
             .stagedStoreRowCountMismatch,
             .stagedStoreProtectedDataMismatch,
             .cacheRecoveryBlockedByProtectedData,
             .cacheRecoveryFailed:
            return false
        }
    }
}
