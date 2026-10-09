import CoreData
import IrohaCrypto
import SoraKeystore
import SQLite3
import SSFModels
import XCTest
@testable import fearless

final class UserStorageCompatibilityMigrationTests: XCTestCase {
    private struct ChainSnapshot: Equatable {
        let chainId: String
        let accountId: String
        let publicKey: Data
        let cryptoType: Int16
        let ecosystem: String?
    }

    private struct WalletSnapshot: Equatable {
        let metaId: String
        let name: String
        let substrateAccountId: String?
        let substratePublicKey: Data?
        let tonAddress: Data?
        let tonPublicKey: Data?
        let tonContractVersion: String?
        let assetsVisibility: [String: Bool]
        let chainAccounts: [ChainSnapshot]
    }

    private let legacyChecksum = "+oGDYB1AZIk54P/liFbJ3aXArqvhW7YLFAy04AChJ+s="
    private let currentChecksum = "dX3y/Aa+rMRI3ZxRibOGIkyCHwrc0zgNO9OoBnS5G/Y="

    private var testDirectory: URL!
    private var storeURL: URL {
        testDirectory.appendingPathComponent("UserDataModel.sqlite")
    }

    private var appBundle: Bundle {
        Bundle(for: UserDataStorageFacade.self)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UserStorageCompatibilityMigrationTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }

        try super.tearDownWithError()
    }

    func testCrashConsistentReplacement_whenProcessDiesAtEveryCommitBoundary_thenBothStoreFamiliesRecoverExactly() throws {
        let scenarios: [
            (
                boundary: CrashConsistentStoreReplacementBoundary,
                shouldCommit: Bool
            )
        ] = [
            (.preparingMarkerPersisted, false),
            (.backupFileCopied(""), false),
            (.backupFileCopied("-wal"), false),
            (.backupFileCopied("-shm"), false),
            (.backupFileCopied("-journal"), false),
            (.committingMarkerPersisted, false),
            (.replacementReturned, false),
            (.destinationValidated, false),
            (.destinationFamilySynced, false),
            (.committedMarkerPersisted, true),
            (.cleanupBackupFileRemoved(""), true),
            (.cleanupBackupFileRemoved("-wal"), true),
            (.cleanupBackupFileRemoved("-shm"), true),
            (.cleanupBackupFileRemoved("-journal"), true),
            (.cleanupBackupDirectoryRemoved, true),
            (.cleanupMarkerRemoved, true),
            (.cleanupTransactionDirectoryRemoved, true),
            (.cleanupRecoveryRootRemoved, true),
            (.transactionCleaned, true)
        ]

        for storeName in [
            "UserDataModel.sqlite",
            "SubstrateDataModel.sqlite"
        ] {
            for (index, scenario) in scenarios.enumerated() {
                let scenarioDirectory = try makeSyntheticScenarioDirectory(
                    "\(storeName)-commit-\(index)"
                )
                let liveStoreURL = scenarioDirectory
                    .appendingPathComponent(storeName)
                let stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged-\(storeName)")
                try writeSyntheticStoreFamily(
                    at: liveStoreURL,
                    seed: 0x10
                )
                try writeSyntheticStoreFamily(
                    at: stagedStoreURL,
                    seed: 0xA0
                )
                let originalFamily = try syntheticStoreFamilySnapshot(
                    at: liveStoreURL
                )
                let committedFamily = try syntheticStoreFamilySnapshot(
                    at: stagedStoreURL
                )
                var didInterrupt = false
                let replacer = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: replaceSyntheticStoreFamily,
                    boundaryHook: { boundary in
                        guard
                            !didInterrupt,
                            boundary == scenario.boundary
                        else {
                            return
                        }

                        didInterrupt = true
                        throw CrashConsistentStoreReplacementInterruption
                            .simulatedProcessDeath
                    }
                )

                XCTAssertThrowsError(
                    try replacer.replaceStore(
                        with: stagedStoreURL,
                        validateDestination: { _ in }
                    ),
                    "\(storeName) \(scenario.boundary)"
                ) { error in
                    guard
                        let interruption = error as? CrashConsistentStoreReplacementInterruption,
                        case .simulatedProcessDeath = interruption
                    else {
                        return XCTFail("Unexpected error: \(error)")
                    }
                }
                XCTAssertTrue(
                    didInterrupt,
                    "The requested boundary was not reached"
                )

                let relaunched = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: replaceSyntheticStoreFamily
                )
                try relaunched.reconcile { _ in }

                XCTAssertEqual(
                    try syntheticStoreFamilySnapshot(at: liveStoreURL),
                    scenario.shouldCommit
                        ? committedFamily
                        : originalFamily,
                    "\(storeName) \(scenario.boundary)"
                )
                XCTAssertFalse(relaunched.hasPendingTransaction)
            }
        }
    }

    func testCrashConsistentReplacement_whenProcessDiesAtEveryRollbackFileBoundary_thenBothStoreFamiliesRestoreExactly() throws {
        let rollbackBoundaries: [
            CrashConsistentStoreReplacementBoundary
        ] = [
            .rollbackMarkerPersisted,
            .liveFileRemoved(""),
            .liveFileRemoved("-wal"),
            .liveFileRemoved("-shm"),
            .liveFileRemoved("-journal"),
            .rollbackTemporaryFileCopied(""),
            .rollbackTemporaryFileCopied("-wal"),
            .rollbackTemporaryFileCopied("-shm"),
            .rollbackTemporaryFileCopied("-journal"),
            .rollbackFileInstalled(""),
            .rollbackFileInstalled("-wal"),
            .rollbackFileInstalled("-shm"),
            .rollbackFileInstalled("-journal"),
            .rollbackFamilyVerified,
            .cleanupBackupFileRemoved(""),
            .cleanupBackupFileRemoved("-wal"),
            .cleanupBackupFileRemoved("-shm"),
            .cleanupBackupFileRemoved("-journal"),
            .cleanupBackupDirectoryRemoved,
            .cleanupMarkerRemoved,
            .cleanupTransactionDirectoryRemoved,
            .cleanupRecoveryRootRemoved,
            .transactionCleaned
        ]

        for storeName in [
            "UserDataModel.sqlite",
            "SubstrateDataModel.sqlite"
        ] {
            for (index, requestedBoundary) in
                rollbackBoundaries.enumerated() {
                let scenarioDirectory = try makeSyntheticScenarioDirectory(
                    "\(storeName)-rollback-\(index)"
                )
                let liveStoreURL = scenarioDirectory
                    .appendingPathComponent(storeName)
                let stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged-\(storeName)")
                try writeSyntheticStoreFamily(
                    at: liveStoreURL,
                    seed: 0x20
                )
                try writeSyntheticStoreFamily(
                    at: stagedStoreURL,
                    seed: 0xB0
                )
                let originalFamily = try syntheticStoreFamilySnapshot(
                    at: liveStoreURL
                )
                var didInterrupt = false
                let replacer = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: { targetURL, sourceURL in
                        try self.replaceSyntheticStoreFamily(
                            at: targetURL,
                            with: sourceURL
                        )
                        throw UserStorageCommitTestError
                            .storeReplacementFailed
                    },
                    boundaryHook: { boundary in
                        guard
                            !didInterrupt,
                            boundary == requestedBoundary
                        else {
                            return
                        }

                        didInterrupt = true
                        throw CrashConsistentStoreReplacementInterruption
                            .simulatedProcessDeath
                    }
                )

                XCTAssertThrowsError(
                    try replacer.replaceStore(
                        with: stagedStoreURL,
                        validateDestination: { _ in }
                    ),
                    "\(storeName) \(requestedBoundary)"
                )
                XCTAssertTrue(
                    didInterrupt,
                    "The requested rollback boundary was not reached"
                )

                let relaunched = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: replaceSyntheticStoreFamily
                )
                try relaunched.reconcile { _ in }

                XCTAssertEqual(
                    try syntheticStoreFamilySnapshot(at: liveStoreURL),
                    originalFamily,
                    "\(storeName) \(requestedBoundary)"
                )
                XCTAssertFalse(relaunched.hasPendingTransaction)
            }
        }
    }

    func testCrashConsistentReplacement_whenProcessDiesDuringEveryCleanupDeletion_thenPreparingRollbackAndCommittedStatesConverge() throws {
        let cleanupBoundaries: [
            CrashConsistentStoreReplacementBoundary
        ] = [
            .cleanupMarkerTemporaryRemoved,
            .cleanupBackupFileRemoved(""),
            .cleanupBackupFileRemoved("-wal"),
            .cleanupBackupFileRemoved("-shm"),
            .cleanupBackupFileRemoved("-journal"),
            .cleanupBackupDirectoryRemoved,
            .cleanupMarkerRemoved,
            .cleanupTransactionDirectoryRemoved,
            .cleanupRecoveryRootRemoved,
            .transactionCleaned
        ]

        for transactionState in [
            "preparing",
            "rolling-back",
            "committed"
        ] {
            for (index, cleanupBoundary) in
                cleanupBoundaries.enumerated() {
                let scenarioDirectory = try makeSyntheticScenarioDirectory(
                    "cleanup-\(transactionState)-\(index)"
                )
                let liveStoreURL = scenarioDirectory
                    .appendingPathComponent("UserDataModel.sqlite")
                let stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged.sqlite")
                try writeSyntheticStoreFamily(
                    at: liveStoreURL,
                    seed: 0x24
                )
                try writeSyntheticStoreFamily(
                    at: stagedStoreURL,
                    seed: 0xB4
                )
                let originalFamily = try syntheticStoreFamilySnapshot(
                    at: liveStoreURL
                )
                let committedFamily = try syntheticStoreFamilySnapshot(
                    at: stagedStoreURL
                )
                var didCreateInterruptedState = false
                let stateCreator = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: { targetURL, sourceURL in
                        try self.replaceSyntheticStoreFamily(
                            at: targetURL,
                            with: sourceURL
                        )
                        if transactionState == "rolling-back" {
                            throw UserStorageCommitTestError
                                .storeReplacementFailed
                        }
                    },
                    boundaryHook: { boundary in
                        let requestedBoundary:
                            CrashConsistentStoreReplacementBoundary
                        switch transactionState {
                        case "preparing":
                            requestedBoundary =
                                .backupFileCopied("-journal")
                        case "rolling-back":
                            requestedBoundary =
                                .rollbackFamilyVerified
                        case "committed":
                            requestedBoundary =
                                .committedMarkerPersisted
                        default:
                            return
                        }

                        guard
                            !didCreateInterruptedState,
                            boundary == requestedBoundary
                        else {
                            return
                        }
                        didCreateInterruptedState = true
                        throw CrashConsistentStoreReplacementInterruption
                            .simulatedProcessDeath
                    }
                )
                XCTAssertThrowsError(
                    try stateCreator.replaceStore(
                        with: stagedStoreURL,
                        validateDestination: { _ in }
                    )
                )
                XCTAssertTrue(didCreateInterruptedState)

                let pendingMarkerURL =
                    stateCreator.transactionDirectoryURL
                        .appendingPathComponent(
                            "transaction.json.pending"
                        )
                try Data("bounded-incomplete-marker".utf8)
                    .write(to: pendingMarkerURL)

                var didInterruptCleanup = false
                let cleanupAttempt = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: replaceSyntheticStoreFamily,
                    boundaryHook: { boundary in
                        guard
                            !didInterruptCleanup,
                            boundary == cleanupBoundary
                        else {
                            return
                        }
                        didInterruptCleanup = true
                        throw CrashConsistentStoreReplacementInterruption
                            .simulatedProcessDeath
                    }
                )
                XCTAssertThrowsError(
                    try cleanupAttempt.reconcile { _ in },
                    "\(transactionState) \(cleanupBoundary)"
                )
                XCTAssertTrue(
                    didInterruptCleanup,
                    "Cleanup boundary was not reached"
                )

                let relaunched = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: replaceSyntheticStoreFamily
                )
                try relaunched.reconcile { _ in }

                XCTAssertEqual(
                    try syntheticStoreFamilySnapshot(at: liveStoreURL),
                    transactionState == "committed"
                        ? committedFamily
                        : originalFamily,
                    "\(transactionState) \(cleanupBoundary)"
                )
                XCTAssertFalse(relaunched.hasPendingTransaction)
            }
        }
    }

    func testCrashConsistentReplacement_whenProcessDiesDuringEachLowLevelFamilyMutation_thenBothStoreFamiliesRestoreExactly() throws {
        let suffixes =
            CrashConsistentStoreReplacer.storeFamilySuffixes

        for storeName in [
            "UserDataModel.sqlite",
            "SubstrateDataModel.sqlite"
        ] {
            for interruptionIndex in 0 ..< suffixes.count * 2 {
                let scenarioDirectory = try makeSyntheticScenarioDirectory(
                    "\(storeName)-partial-\(interruptionIndex)"
                )
                let liveStoreURL = scenarioDirectory
                    .appendingPathComponent(storeName)
                let stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged-\(storeName)")
                try writeSyntheticStoreFamily(
                    at: liveStoreURL,
                    seed: 0x30
                )
                try writeSyntheticStoreFamily(
                    at: stagedStoreURL,
                    seed: 0xC0
                )
                let originalFamily = try syntheticStoreFamilySnapshot(
                    at: liveStoreURL
                )
                let replacer = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: { targetURL, sourceURL in
                        for (index, suffix) in suffixes.enumerated() {
                            try FileManager.default.removeItem(
                                at: self.syntheticFamilyURL(
                                    targetURL,
                                    suffix: suffix
                                )
                            )
                            if index == interruptionIndex {
                                throw CrashConsistentStoreReplacementInterruption
                                    .simulatedProcessDeath
                            }
                        }

                        for (index, suffix) in suffixes.enumerated() {
                            try FileManager.default.copyItem(
                                at: self.syntheticFamilyURL(
                                    sourceURL,
                                    suffix: suffix
                                ),
                                to: self.syntheticFamilyURL(
                                    targetURL,
                                    suffix: suffix
                                )
                            )
                            if suffixes.count + index ==
                                interruptionIndex {
                                throw CrashConsistentStoreReplacementInterruption
                                    .simulatedProcessDeath
                            }
                        }
                    }
                )

                XCTAssertThrowsError(
                    try replacer.replaceStore(
                        with: stagedStoreURL,
                        validateDestination: { _ in }
                    )
                )
                XCTAssertFalse(
                    FileManager.default.fileExists(
                        atPath: liveStoreURL.path
                    ) && interruptionIndex == 0
                )

                let relaunched = CrashConsistentStoreReplacer(
                    storeURL: liveStoreURL,
                    fileManager: .default,
                    storeReplacer: replaceSyntheticStoreFamily
                )
                try relaunched.reconcile { _ in }

                XCTAssertEqual(
                    try syntheticStoreFamilySnapshot(at: liveStoreURL),
                    originalFamily,
                    "\(storeName) mutation \(interruptionIndex)"
                )
                XCTAssertFalse(relaunched.hasPendingTransaction)
            }
        }
    }

    func testCrashConsistentReplacement_whenFirstMarkerWriteIsInterrupted_thenOnlyExactSafePendingTreeIsCleaned() throws {
        let recoverableDirectory = try makeSyntheticScenarioDirectory(
            "markerless-pending-recoverable"
        )
        let recoverableStoreURL = recoverableDirectory
            .appendingPathComponent("UserDataModel.sqlite")
        try writeSyntheticStoreFamily(
            at: recoverableStoreURL,
            seed: 0x38
        )
        let recoverableFamily = try syntheticStoreFamilySnapshot(
            at: recoverableStoreURL
        )
        let recoverableReplacer = CrashConsistentStoreReplacer(
            storeURL: recoverableStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        try FileManager.default.createDirectory(
            at: recoverableReplacer.transactionDirectoryURL,
            withIntermediateDirectories: true
        )
        let recoverablePendingURL =
            recoverableReplacer.transactionDirectoryURL
                .appendingPathComponent("transaction.json.pending")
        try Data("{\"schemaVersion\":1".utf8).write(
            to: recoverablePendingURL
        )

        try recoverableReplacer.reconcile { _ in }

        XCTAssertEqual(
            try syntheticStoreFamilySnapshot(at: recoverableStoreURL),
            recoverableFamily
        )
        XCTAssertFalse(recoverableReplacer.hasPendingTransaction)

        let unknownDirectory = try makeSyntheticScenarioDirectory(
            "markerless-pending-unknown"
        )
        let unknownStoreURL = unknownDirectory
            .appendingPathComponent("UserDataModel.sqlite")
        try writeSyntheticStoreFamily(at: unknownStoreURL, seed: 0x39)
        let unknownFamily = try syntheticStoreFamilySnapshot(
            at: unknownStoreURL
        )
        let unknownReplacer = CrashConsistentStoreReplacer(
            storeURL: unknownStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        try FileManager.default.createDirectory(
            at: unknownReplacer.transactionDirectoryURL,
            withIntermediateDirectories: true
        )
        let unknownPendingURL = unknownReplacer.transactionDirectoryURL
            .appendingPathComponent("transaction.json.pending")
        let unrelatedURL = unknownReplacer.transactionDirectoryURL
            .appendingPathComponent("unrelated")
        try Data("partial-marker".utf8).write(to: unknownPendingURL)
        try Data("must-survive".utf8).write(to: unrelatedURL)

        XCTAssertThrowsError(
            try unknownReplacer.reconcile { _ in }
        )
        XCTAssertEqual(
            try Data(contentsOf: unknownPendingURL),
            Data("partial-marker".utf8)
        )
        XCTAssertEqual(
            try Data(contentsOf: unrelatedURL),
            Data("must-survive".utf8)
        )
        XCTAssertEqual(
            try syntheticStoreFamilySnapshot(at: unknownStoreURL),
            unknownFamily
        )
        XCTAssertTrue(unknownReplacer.hasPendingTransaction)

        let symlinkDirectory = try makeSyntheticScenarioDirectory(
            "markerless-pending-symlink"
        )
        let symlinkStoreURL = symlinkDirectory
            .appendingPathComponent("UserDataModel.sqlite")
        try writeSyntheticStoreFamily(at: symlinkStoreURL, seed: 0x3A)
        let symlinkFamily = try syntheticStoreFamilySnapshot(
            at: symlinkStoreURL
        )
        let symlinkReplacer = CrashConsistentStoreReplacer(
            storeURL: symlinkStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        try FileManager.default.createDirectory(
            at: symlinkReplacer.transactionDirectoryURL,
            withIntermediateDirectories: true
        )
        let symlinkTargetURL = symlinkDirectory
            .appendingPathComponent("pending-target")
        try Data("must-survive".utf8).write(to: symlinkTargetURL)
        try FileManager.default.createSymbolicLink(
            at: symlinkReplacer.transactionDirectoryURL
                .appendingPathComponent("transaction.json.pending"),
            withDestinationURL: symlinkTargetURL
        )

        XCTAssertThrowsError(
            try symlinkReplacer.reconcile { _ in }
        )
        XCTAssertEqual(
            try Data(contentsOf: symlinkTargetURL),
            Data("must-survive".utf8)
        )
        XCTAssertEqual(
            try syntheticStoreFamilySnapshot(at: symlinkStoreURL),
            symlinkFamily
        )
        XCTAssertTrue(symlinkReplacer.hasPendingTransaction)
    }

    func testCrashConsistentReplacement_whenPreparingBackupCopyIsPartial_thenCleansOnlyWithExactOriginalLiveFamily() throws {
        for liveFamilyChanged in [false, true] {
            let scenarioDirectory = try makeSyntheticScenarioDirectory(
                liveFamilyChanged
                    ? "partial-preparing-backup-changed-live"
                    : "partial-preparing-backup-exact-live"
            )
            let liveStoreURL = scenarioDirectory
                .appendingPathComponent("UserDataModel.sqlite")
            let stagedStoreURL = scenarioDirectory
                .appendingPathComponent("Staged.sqlite")
            try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x3B)
            try writeSyntheticStoreFamily(at: stagedStoreURL, seed: 0xCB)
            let originalFamily = try syntheticStoreFamilySnapshot(
                at: liveStoreURL
            )
            let interrupted = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily,
                boundaryHook: { boundary in
                    guard boundary == .preparingMarkerPersisted else {
                        return
                    }
                    throw CrashConsistentStoreReplacementInterruption
                        .simulatedProcessDeath
                }
            )
            XCTAssertThrowsError(
                try interrupted.replaceStore(
                    with: stagedStoreURL,
                    validateDestination: { _ in }
                )
            )

            let backupDirectoryURL =
                interrupted.transactionDirectoryURL
                    .appendingPathComponent(
                        "OriginalStoreFamily",
                        isDirectory: true
                    )
            try FileManager.default.createDirectory(
                at: backupDirectoryURL,
                withIntermediateDirectories: false
            )
            let partialBackupURL = backupDirectoryURL
                .appendingPathComponent(liveStoreURL.lastPathComponent)
            try Data("partial-copy".utf8).write(to: partialBackupURL)

            if liveFamilyChanged {
                try Data("changed-live-main".utf8).write(
                    to: liveStoreURL
                )
            }
            let familyBeforeReconcile =
                try syntheticStoreFamilySnapshot(at: liveStoreURL)
            let relaunched = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily
            )

            if liveFamilyChanged {
                XCTAssertThrowsError(
                    try relaunched.reconcile { _ in }
                )
                XCTAssertEqual(
                    try syntheticStoreFamilySnapshot(at: liveStoreURL),
                    familyBeforeReconcile
                )
                XCTAssertEqual(
                    try Data(contentsOf: partialBackupURL),
                    Data("partial-copy".utf8)
                )
                XCTAssertTrue(relaunched.hasPendingTransaction)
            } else {
                try relaunched.reconcile { _ in }
                XCTAssertEqual(
                    try syntheticStoreFamilySnapshot(at: liveStoreURL),
                    originalFamily
                )
                XCTAssertFalse(relaunched.hasPendingTransaction)
            }
        }
    }

    func testCrashConsistentReplacement_whenMarkerIsAdversarial_thenFailsClosedWithoutChangingLiveFamily() throws {
        for mutation in [
            "duplicate-member",
            "path-traversal",
            "digest-mismatch",
            "size-mismatch",
            "noncanonical-order",
            "top-duplicate-field",
            "top-unknown-field",
            "member-duplicate-field",
            "member-unknown-field",
            "escaped-field-name",
            "wrong-top-field-type",
            "wrong-member-field-type",
            "wrong-family-container-type",
            "oversized",
            "markerless-nonempty"
        ] {
            let scenarioDirectory = try makeSyntheticScenarioDirectory(
                "adversarial-\(mutation)"
            )
            let liveStoreURL = scenarioDirectory
                .appendingPathComponent("UserDataModel.sqlite")
            let stagedStoreURL = scenarioDirectory
                .appendingPathComponent("Staged.sqlite")
            try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x40)
            try writeSyntheticStoreFamily(at: stagedStoreURL, seed: 0xD0)
            let originalFamily = try syntheticStoreFamilySnapshot(
                at: liveStoreURL
            )
            var didInterrupt = false
            let interrupted = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily,
                boundaryHook: { boundary in
                    guard
                        !didInterrupt,
                        boundary == .committingMarkerPersisted
                    else {
                        return
                    }

                    didInterrupt = true
                    throw CrashConsistentStoreReplacementInterruption
                        .simulatedProcessDeath
                }
            )
            XCTAssertThrowsError(
                try interrupted.replaceStore(
                    with: stagedStoreURL,
                    validateDestination: { _ in }
                )
            )
            XCTAssertTrue(didInterrupt)

            let markerURL = interrupted.transactionDirectoryURL
                .appendingPathComponent("transaction.json")
            if mutation == "oversized" {
                try Data(repeating: 0x7B, count: 64 * 1024 + 1)
                    .write(to: markerURL)
            } else if mutation == "markerless-nonempty" {
                try FileManager.default.removeItem(at: markerURL)
            } else if [
                "top-duplicate-field",
                "top-unknown-field",
                "member-duplicate-field",
                "member-unknown-field",
                "escaped-field-name",
                "wrong-top-field-type",
                "wrong-member-field-type"
            ].contains(mutation) {
                let originalJSON = try XCTUnwrap(
                    String(
                        data: Data(contentsOf: markerURL),
                        encoding: .utf8
                    )
                )
                let mutatedJSON: String
                switch mutation {
                case "top-duplicate-field":
                    mutatedJSON =
                        String(originalJSON.dropLast()) +
                        ",\"state\":\"committing\"}"
                case "top-unknown-field":
                    mutatedJSON =
                        String(originalJSON.dropLast()) +
                        ",\"unexpected\":true}"
                case "member-duplicate-field":
                    mutatedJSON = originalJSON.replacingOccurrences(
                        of: "\"suffix\":\"\"",
                        with: "\"suffix\":\"\",\"suffix\":\"\""
                    )
                case "member-unknown-field":
                    mutatedJSON = originalJSON.replacingOccurrences(
                        of: "\"suffix\":\"\"",
                        with: "\"suffix\":\"\",\"unexpected\":0"
                    )
                case "escaped-field-name":
                    mutatedJSON = originalJSON.replacingOccurrences(
                        of: "\"state\"",
                        with: "\"st\\u0061te\""
                    )
                case "wrong-top-field-type":
                    mutatedJSON = originalJSON.replacingOccurrences(
                        of: "\"schemaVersion\":1",
                        with: "\"schemaVersion\":\"1\""
                    )
                case "wrong-member-field-type":
                    mutatedJSON = originalJSON.replacingOccurrences(
                        of: "\"byteCount\":31",
                        with: "\"byteCount\":\"31\""
                    )
                default:
                    throw UserStorageCommitTestError
                        .storeReplacementFailed
                }
                XCTAssertNotEqual(mutatedJSON, originalJSON)
                try Data(mutatedJSON.utf8).write(to: markerURL)
            } else {
                var marker = try XCTUnwrap(
                    JSONSerialization.jsonObject(
                        with: Data(contentsOf: markerURL)
                    ) as? [String: Any]
                )
                var family = try XCTUnwrap(
                    marker["originalFamily"]
                        as? [[String: Any]]
                )

                switch mutation {
                case "duplicate-member":
                    family.append(family[0])
                case "path-traversal":
                    family[0]["suffix"] = "../UserDataModel.sqlite"
                case "digest-mismatch":
                    family[0]["sha256"] = String(
                        repeating: "0",
                        count: 64
                    )
                case "size-mismatch":
                    let oldSize = (
                        family[0]["byteCount"] as? NSNumber
                    )?.uint64Value ?? 0
                    family[0]["byteCount"] = NSNumber(
                        value: oldSize + 1
                    )
                case "noncanonical-order":
                    family.reverse()
                case "wrong-family-container-type":
                    marker["originalFamily"] =
                        "not-an-array"
                default:
                    XCTFail("Unhandled mutation \(mutation)")
                }

                if mutation != "wrong-family-container-type" {
                    marker["originalFamily"] = family
                }
                try JSONSerialization.data(
                    withJSONObject: marker,
                    options: [.sortedKeys]
                ).write(to: markerURL)
            }

            let relaunched = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily
            )
            XCTAssertThrowsError(
                try relaunched.reconcile { _ in },
                mutation
            )
            XCTAssertEqual(
                try syntheticStoreFamilySnapshot(at: liveStoreURL),
                originalFamily,
                mutation
            )
            XCTAssertTrue(relaunched.hasPendingTransaction)
        }
    }

    func testCrashConsistentReplacement_whenTransactionTreeContainsUnknownFileOrDirectory_thenFailsClosed() throws {
        for mutation in [
            "top-file",
            "top-directory",
            "backup-file",
            "backup-directory"
        ] {
            let scenarioDirectory = try makeSyntheticScenarioDirectory(
                "unknown-tree-\(mutation)"
            )
            let liveStoreURL = scenarioDirectory
                .appendingPathComponent("UserDataModel.sqlite")
            let stagedStoreURL = scenarioDirectory
                .appendingPathComponent("Staged.sqlite")
            try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x45)
            try writeSyntheticStoreFamily(at: stagedStoreURL, seed: 0xD5)
            let originalFamily = try syntheticStoreFamilySnapshot(
                at: liveStoreURL
            )
            let interrupted = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily,
                boundaryHook: { boundary in
                    guard boundary == .committingMarkerPersisted else {
                        return
                    }
                    throw CrashConsistentStoreReplacementInterruption
                        .simulatedProcessDeath
                }
            )
            XCTAssertThrowsError(
                try interrupted.replaceStore(
                    with: stagedStoreURL,
                    validateDestination: { _ in }
                )
            )

            let backupDirectory = interrupted
                .transactionDirectoryURL
                .appendingPathComponent(
                    "OriginalStoreFamily",
                    isDirectory: true
                )
            let unknownURL: URL
            let isDirectory: Bool
            switch mutation {
            case "top-file":
                unknownURL = interrupted.transactionDirectoryURL
                    .appendingPathComponent("unknown")
                isDirectory = false
            case "top-directory":
                unknownURL = interrupted.transactionDirectoryURL
                    .appendingPathComponent(
                        "UnknownDirectory",
                        isDirectory: true
                    )
                isDirectory = true
            case "backup-file":
                unknownURL = backupDirectory
                    .appendingPathComponent("unknown")
                isDirectory = false
            case "backup-directory":
                unknownURL = backupDirectory
                    .appendingPathComponent(
                        "UnknownDirectory",
                        isDirectory: true
                    )
                isDirectory = true
            default:
                throw UserStorageCommitTestError
                    .storeReplacementFailed
            }

            if isDirectory {
                try FileManager.default.createDirectory(
                    at: unknownURL,
                    withIntermediateDirectories: false
                )
            } else {
                try Data("unknown".utf8).write(to: unknownURL)
            }

            let relaunched = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily
            )
            XCTAssertThrowsError(
                try relaunched.reconcile { _ in },
                mutation
            )
            XCTAssertEqual(
                try syntheticStoreFamilySnapshot(at: liveStoreURL),
                originalFamily
            )
            XCTAssertTrue(relaunched.hasPendingTransaction)
        }
    }

    func testCrashConsistentReplacement_whenCommittedFamilyOrSemanticValidationChanges_thenRestoresOriginalFamily() throws {
        for mutation in [
            "live-bytes",
            "semantic-validation",
            "validator-mutates-live"
        ] {
            let scenarioDirectory = try makeSyntheticScenarioDirectory(
                "committed-\(mutation)"
            )
            let liveStoreURL = scenarioDirectory
                .appendingPathComponent("UserDataModel.sqlite")
            let stagedStoreURL = scenarioDirectory
                .appendingPathComponent("Staged.sqlite")
            try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x50)
            try writeSyntheticStoreFamily(at: stagedStoreURL, seed: 0xE0)
            let originalFamily = try syntheticStoreFamilySnapshot(
                at: liveStoreURL
            )
            var didInterrupt = false
            let interrupted = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily,
                boundaryHook: { boundary in
                    guard
                        !didInterrupt,
                        boundary == .committedMarkerPersisted
                    else {
                        return
                    }

                    didInterrupt = true
                    throw CrashConsistentStoreReplacementInterruption
                        .simulatedProcessDeath
                }
            )
            XCTAssertThrowsError(
                try interrupted.replaceStore(
                    with: stagedStoreURL,
                    validateDestination: { _ in }
                )
            )

            if mutation == "live-bytes" {
                try Data("tampered-after-commit".utf8).write(
                    to: liveStoreURL
                )
            }

            let relaunched = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily
            )
            try relaunched.reconcile { _ in
                if mutation == "semantic-validation" {
                    throw UserStorageCommitTestError
                        .storeReplacementFailed
                } else if mutation == "validator-mutates-live" {
                    try Data("validator-mutated-live".utf8).write(
                        to: liveStoreURL
                    )
                }
            }

            XCTAssertEqual(
                try syntheticStoreFamilySnapshot(at: liveStoreURL),
                originalFamily,
                mutation
            )
            XCTAssertFalse(relaunched.hasPendingTransaction)
        }
    }

    func testCrashConsistentReplacement_whenCommittedValidationMutatesItsStoreAndCleanupIsInterrupted_thenLiveCommitStillConverges() throws {
        let scenarioDirectory = try makeSyntheticScenarioDirectory(
            "committed-private-validation"
        )
        let liveStoreURL = scenarioDirectory
            .appendingPathComponent("UserDataModel.sqlite")
        let stagedStoreURL = scenarioDirectory
            .appendingPathComponent("Staged.sqlite")
        try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x52)
        try writeSyntheticStoreFamily(at: stagedStoreURL, seed: 0xE2)
        let committedFamily = try syntheticStoreFamilySnapshot(
            at: stagedStoreURL
        )
        let interrupted = CrashConsistentStoreReplacer(
            storeURL: liveStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily,
            boundaryHook: { boundary in
                guard boundary == .committedMarkerPersisted else {
                    return
                }
                throw CrashConsistentStoreReplacementInterruption
                    .simulatedProcessDeath
            }
        )
        XCTAssertThrowsError(
            try interrupted.replaceStore(
                with: stagedStoreURL,
                validateDestination: { _ in }
            )
        )

        var validationStoreURL: URL?
        var didInterruptCleanup = false
        let cleanupAttempt = CrashConsistentStoreReplacer(
            storeURL: liveStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily,
            boundaryHook: { boundary in
                guard
                    !didInterruptCleanup,
                    boundary == .cleanupBackupFileRemoved("")
                else {
                    return
                }
                didInterruptCleanup = true
                throw CrashConsistentStoreReplacementInterruption
                    .simulatedProcessDeath
            }
        )
        XCTAssertThrowsError(
            try cleanupAttempt.reconcile { privateStoreURL in
                validationStoreURL = privateStoreURL
                XCTAssertNotEqual(
                    privateStoreURL.standardizedFileURL,
                    liveStoreURL.standardizedFileURL
                )

                for suffix in
                    CrashConsistentStoreReplacer.storeFamilySuffixes {
                    let memberURL = self.syntheticFamilyURL(
                        privateStoreURL,
                        suffix: suffix
                    )
                    guard FileManager.default.fileExists(
                        atPath: memberURL.path
                    ) else {
                        continue
                    }
                    try Data("validator-mutated-\(suffix)".utf8)
                        .write(to: memberURL)
                }
            }
        )
        XCTAssertTrue(didInterruptCleanup)
        XCTAssertEqual(
            try syntheticStoreFamilySnapshot(at: liveStoreURL),
            committedFamily
        )
        let capturedValidationStoreURL = try XCTUnwrap(
            validationStoreURL
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: capturedValidationStoreURL.path
            )
        )

        let relaunched = CrashConsistentStoreReplacer(
            storeURL: liveStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        try relaunched.reconcile { privateStoreURL in
            XCTAssertNotEqual(
                privateStoreURL.standardizedFileURL,
                liveStoreURL.standardizedFileURL
            )
            XCTAssertEqual(
                try self.syntheticStoreFamilySnapshot(
                    at: privateStoreURL
                ),
                committedFamily
            )
        }

        XCTAssertEqual(
            try syntheticStoreFamilySnapshot(at: liveStoreURL),
            committedFamily
        )
        XCTAssertFalse(relaunched.hasPendingTransaction)
    }

    func testCrashConsistentReplacement_whenMarkerBackupOrLiveMemberIsSymlink_thenFailsClosed() throws {
        for mutation in ["marker", "backup-main", "live-main"] {
            let scenarioDirectory = try makeSyntheticScenarioDirectory(
                "symlink-\(mutation)"
            )
            let liveStoreURL = scenarioDirectory
                .appendingPathComponent("UserDataModel.sqlite")
            let stagedStoreURL = scenarioDirectory
                .appendingPathComponent("Staged.sqlite")
            try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x55)
            try writeSyntheticStoreFamily(at: stagedStoreURL, seed: 0xF0)
            var didInterrupt = false
            let interrupted = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily,
                boundaryHook: { boundary in
                    guard
                        !didInterrupt,
                        boundary == .committingMarkerPersisted
                    else {
                        return
                    }

                    didInterrupt = true
                    throw CrashConsistentStoreReplacementInterruption
                        .simulatedProcessDeath
                }
            )
            XCTAssertThrowsError(
                try interrupted.replaceStore(
                    with: stagedStoreURL,
                    validateDestination: { _ in }
                )
            )

            let markerURL = interrupted.transactionDirectoryURL
                .appendingPathComponent("transaction.json")
            let backupMainURL = interrupted.transactionDirectoryURL
                .appendingPathComponent(
                    "OriginalStoreFamily",
                    isDirectory: true
                )
                .appendingPathComponent(liveStoreURL.lastPathComponent)

            switch mutation {
            case "marker":
                let displacedURL = scenarioDirectory
                    .appendingPathComponent("DisplacedMarker")
                try FileManager.default.moveItem(
                    at: markerURL,
                    to: displacedURL
                )
                try FileManager.default.createSymbolicLink(
                    at: markerURL,
                    withDestinationURL: displacedURL
                )
            case "backup-main":
                try FileManager.default.removeItem(at: backupMainURL)
                try FileManager.default.createSymbolicLink(
                    at: backupMainURL,
                    withDestinationURL: liveStoreURL
                )
            case "live-main":
                let displacedURL = scenarioDirectory
                    .appendingPathComponent("DisplacedLiveMain")
                try FileManager.default.moveItem(
                    at: liveStoreURL,
                    to: displacedURL
                )
                try FileManager.default.createSymbolicLink(
                    at: liveStoreURL,
                    withDestinationURL: displacedURL
                )
            default:
                XCTFail("Unhandled mutation \(mutation)")
            }

            let relaunched = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: replaceSyntheticStoreFamily
            )
            XCTAssertThrowsError(
                try relaunched.reconcile { _ in },
                mutation
            )
            XCTAssertTrue(relaunched.hasPendingTransaction)
        }
    }

    func testCrashConsistentReplacement_whenLiveFamilyIsUnsafeOrOrphaned_thenNeverReportsAnEmptyStore() throws {
        let orphanDirectory = try makeSyntheticScenarioDirectory(
            "orphan-sidecar"
        )
        let orphanStoreURL = orphanDirectory
            .appendingPathComponent("UserDataModel.sqlite")
        try Data("orphan-wal".utf8).write(
            to: syntheticFamilyURL(
                orphanStoreURL,
                suffix: "-wal"
            )
        )
        let orphanReplacer = CrashConsistentStoreReplacer(
            storeURL: orphanStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        XCTAssertThrowsError(
            try orphanReplacer.liveStoreExistsSafely()
        )

        let symlinkDirectory = try makeSyntheticScenarioDirectory(
            "symlink-sidecar"
        )
        let symlinkStoreURL = symlinkDirectory
            .appendingPathComponent("SubstrateDataModel.sqlite")
        try Data("main".utf8).write(to: symlinkStoreURL)
        let symlinkTargetURL = symlinkDirectory
            .appendingPathComponent("SidecarTarget")
        try Data("target".utf8).write(to: symlinkTargetURL)
        try FileManager.default.createSymbolicLink(
            at: syntheticFamilyURL(
                symlinkStoreURL,
                suffix: "-shm"
            ),
            withDestinationURL: symlinkTargetURL
        )
        let symlinkReplacer = CrashConsistentStoreReplacer(
            storeURL: symlinkStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        XCTAssertThrowsError(
            try symlinkReplacer.liveStoreExistsSafely()
        )

        let directoryStoreRoot = try makeSyntheticScenarioDirectory(
            "directory-main"
        )
        let directoryStoreURL = directoryStoreRoot
            .appendingPathComponent("UserDataModel.sqlite")
        try FileManager.default.createDirectory(
            at: directoryStoreURL,
            withIntermediateDirectories: false
        )
        let directoryReplacer = CrashConsistentStoreReplacer(
            storeURL: directoryStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        XCTAssertThrowsError(
            try directoryReplacer.liveStoreExistsSafely()
        )
    }

    func testCrashConsistentReplacement_whenStagedFamilyIsUnsafeOrAliasesProtectedPaths_thenRejectsBeforeMutation() throws {
        for mutation in [
            "same-live-path",
            "dotdot-live-alias",
            "hardlink-main",
            "intra-family-hardlink",
            "symlink-main",
            "symlink-sidecar",
            "orphan-sidecar",
            "inside-recovery-root"
        ] {
            let scenarioDirectory = try makeSyntheticScenarioDirectory(
                "unsafe-stage-\(mutation)"
            )
            let liveStoreURL = scenarioDirectory
                .appendingPathComponent("UserDataModel.sqlite")
            try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x5A)
            let originalFamily = try syntheticStoreFamilySnapshot(
                at: liveStoreURL
            )
            let stagedStoreURL: URL

            switch mutation {
            case "same-live-path":
                stagedStoreURL = liveStoreURL
            case "dotdot-live-alias":
                let aliasDirectory = scenarioDirectory
                    .appendingPathComponent(
                        "Alias",
                        isDirectory: true
                    )
                try FileManager.default.createDirectory(
                    at: aliasDirectory,
                    withIntermediateDirectories: false
                )
                stagedStoreURL = URL(
                    fileURLWithPath:
                    "\(aliasDirectory.path)/../\(liveStoreURL.lastPathComponent)"
                )
            case "hardlink-main":
                stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged.sqlite")
                try FileManager.default.linkItem(
                    at: liveStoreURL,
                    to: stagedStoreURL
                )
            case "intra-family-hardlink":
                stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged.sqlite")
                try writeSyntheticStoreFamily(
                    at: stagedStoreURL,
                    seed: 0xEA
                )
                let stagedWALURL = syntheticFamilyURL(
                    stagedStoreURL,
                    suffix: "-wal"
                )
                try FileManager.default.removeItem(at: stagedWALURL)
                try FileManager.default.linkItem(
                    at: stagedStoreURL,
                    to: stagedWALURL
                )
            case "symlink-main":
                stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged.sqlite")
                try FileManager.default.createSymbolicLink(
                    at: stagedStoreURL,
                    withDestinationURL: liveStoreURL
                )
            case "symlink-sidecar":
                stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged.sqlite")
                try Data("staged-main".utf8).write(
                    to: stagedStoreURL
                )
                try FileManager.default.createSymbolicLink(
                    at: syntheticFamilyURL(
                        stagedStoreURL,
                        suffix: "-wal"
                    ),
                    withDestinationURL: syntheticFamilyURL(
                        liveStoreURL,
                        suffix: "-wal"
                    )
                )
            case "orphan-sidecar":
                stagedStoreURL = scenarioDirectory
                    .appendingPathComponent("Staged.sqlite")
                try Data("orphan-staged-wal".utf8).write(
                    to: syntheticFamilyURL(
                        stagedStoreURL,
                        suffix: "-wal"
                    )
                )
            case "inside-recovery-root":
                let recoveryDirectory = scenarioDirectory
                    .appendingPathComponent(
                        ".FearlessStoreReplacement/Attacker",
                        isDirectory: true
                    )
                try FileManager.default.createDirectory(
                    at: recoveryDirectory,
                    withIntermediateDirectories: true
                )
                stagedStoreURL = recoveryDirectory
                    .appendingPathComponent("Staged.sqlite")
                try Data("staged-main".utf8).write(
                    to: stagedStoreURL
                )
            default:
                throw UserStorageCommitTestError
                    .storeReplacementFailed
            }

            var replacementWasCalled = false
            let replacer = CrashConsistentStoreReplacer(
                storeURL: liveStoreURL,
                fileManager: .default,
                storeReplacer: { _, _ in
                    replacementWasCalled = true
                }
            )
            XCTAssertThrowsError(
                try replacer.replaceStore(
                    with: stagedStoreURL,
                    validateDestination: { _ in }
                ),
                mutation
            )
            XCTAssertFalse(replacementWasCalled, mutation)
            XCTAssertEqual(
                try syntheticStoreFamilySnapshot(at: liveStoreURL),
                originalFamily,
                mutation
            )
            XCTAssertFalse(replacer.hasPendingTransaction)
        }
    }

    func testCrashConsistentReplacement_whenPreMarkerDirectoryIsEmpty_thenSafelyCleansItOnlyAfterValidatingLiveFamily() throws {
        let scenarioDirectory = try makeSyntheticScenarioDirectory(
            "empty-pre-marker"
        )
        let liveStoreURL = scenarioDirectory
            .appendingPathComponent("UserDataModel.sqlite")
        try writeSyntheticStoreFamily(at: liveStoreURL, seed: 0x58)
        let replacer = CrashConsistentStoreReplacer(
            storeURL: liveStoreURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        try FileManager.default.createDirectory(
            at: replacer.transactionDirectoryURL,
            withIntermediateDirectories: true
        )

        try replacer.reconcile { _ in }

        XCTAssertFalse(replacer.hasPendingTransaction)
        XCTAssertTrue(try replacer.liveStoreExistsSafely())
    }

    func testCrashConsistentReplacement_whenPathsShareDirectory_thenUserAndSubstrateTransactionsCannotCollide() throws {
        try writeSyntheticStoreFamily(at: storeURL, seed: 0x60)
        let substrateURL = testDirectory
            .appendingPathComponent("SubstrateDataModel.sqlite")
        try writeSyntheticStoreFamily(at: substrateURL, seed: 0x70)

        let userReplacer = CrashConsistentStoreReplacer(
            storeURL: storeURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )
        let substrateReplacer = CrashConsistentStoreReplacer(
            storeURL: substrateURL,
            fileManager: .default,
            storeReplacer: replaceSyntheticStoreFamily
        )

        XCTAssertNotEqual(
            userReplacer.transactionDirectoryURL.standardizedFileURL,
            substrateReplacer.transactionDirectoryURL
                .standardizedFileURL
        )
        XCTAssertEqual(
            userReplacer.transactionDirectoryURL
                .deletingLastPathComponent(),
            substrateReplacer.transactionDirectoryURL
                .deletingLastPathComponent()
        )
    }

    func testCompatibilityModels_whenBundled_thenHaveExactFingerprintsAndMigrationEdges() throws {
        let expectedLegacyHashes = [
            "CDAccountInfo": "q3sBYA7JunDkaJOaTevIdD/b1Ou+4Qrdi0twbrghhf8=",
            "CDAssetVisibility": "IYchCCjZ4/tlPbRVhOIyAtOY1J6500tV0GoXt7gb5Ac=",
            "CDChainAccount": "AVvqEhz7A8aiXmrGYNuGkrLTmUy2GdEzHx5uh1rR+6Y=",
            "CDChainSettings": "GHqxJZE9c7xLExSYsWfzpktGdVvQqqFyACPiYKaLgsQ=",
            "CDCurrency": "iF3edtRVNvP9XKRuZuVOU5YFx50BLwbUqlaPKdBHgmk=",
            "CDCustomChainNode": "/mUD0P2skKW0f6ao8jt07yDn3BARGk3Ve9qc2W6Zl8k=",
            "CDMetaAccount": "teqUP1fwr7jL/V0Tm33An9SPbBlLr9L6ioRO8fkPIjA="
        ]
        let expectedCurrentHashes = expectedLegacyHashes.merging(
            ["CDChainAccount": "jvrdZWLn1+K0pe0MCQsxJP2fdOiiAAYkoSJf4x1Y5JU="]
        ) { _, current in current }

        let legacyURL = try directCompatibilityModelURL(for: .version13)
        let currentURL = try directCompatibilityModelURL(for: .version14)
        let legacyModel = try loadModel(at: legacyURL)
        let currentModel = try loadModel(at: currentURL)

        XCTAssertEqual(versionHashes(for: legacyModel), expectedLegacyHashes)
        XCTAssertEqual(versionHashes(for: currentModel), expectedCurrentHashes)
        XCTAssertEqual(
            try storeChecksum(for: legacyModel, named: "legacy-fingerprint.sqlite"),
            legacyChecksum
        )
        XCTAssertEqual(
            try storeChecksum(for: currentModel, named: "current-fingerprint.sqlite"),
            currentChecksum
        )

        XCTAssertEqual(UserStorageVersion.version12.nextVersion(), .version14)
        XCTAssertEqual(UserStorageVersion.version13.nextVersion(), .version14)
        XCTAssertNil(UserStorageVersion.version14.nextVersion())
        XCTAssertEqual(UserStorageVersion.current, .version14)
    }

    func testCurrentModel_whenLoaded_thenEveryEntityResolvesToTheAppRuntimeClass() throws {
        let expectedClasses: [String: NSManagedObject.Type] = [
            "CDAccountInfo": fearless.CDAccountInfo.self,
            "CDAssetVisibility": fearless.CDAssetVisibility.self,
            "CDChainAccount": fearless.CDChainAccount.self,
            "CDChainSettings": fearless.CDChainSettings.self,
            "CDCurrency": fearless.CDCurrency.self,
            "CDCustomChainNode": fearless.CDCustomChainNode.self,
            "CDMetaAccount": fearless.CDMetaAccount.self
        ]
        let currentModel = try model(for: .version14)

        for (entityName, expectedClass) in expectedClasses {
            let entity = try XCTUnwrap(currentModel.entitiesByName[entityName])
            let className = try XCTUnwrap(entity.managedObjectClassName)
            let resolvedClass = try XCTUnwrap(
                NSClassFromString(className) as? NSManagedObject.Type,
                "\(className) must resolve to an NSManagedObject class"
            )

            XCTAssertEqual(
                ObjectIdentifier(resolvedClass),
                ObjectIdentifier(expectedClass),
                "\(entityName) resolved to a different runtime class than the app alias"
            )
        }
    }

    func testMigration_whenVersion2PersistentFixture_thenPreservesWalletsAndAccountsAndRoutesExistingPincodeToPinOnRepeatedLaunch() throws {
        let sourceModel = try model(for: .version2)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertVersion2WalletFixture(
                in: context,
                model: sourceModel
            )
        }
        let pincode = Data("246810".utf8)
        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            pincode,
            with: fearless.KeystoreTag.pincode.rawValue
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertTrue(try migrator.performMigration())
        XCTAssertFalse(try migrator.performMigration())
        XCTAssertEqual(
            try walletSnapshots(
                from: storeURL,
                model: model(for: .version14)
            ),
            version2WalletFixtureSnapshots()
        )

        let facade = UserDataStorageFacade(
            modelURL: UserStorageVersion.version14.modelURL(
                in: appBundle,
                legacyModelDirectory: UserStorageParams.modelDirectory
            ),
            databaseDirectory: testDirectory
        )
        defer {
            try? facade.databaseService.close()
        }
        let selectedWalletSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: OperationQueue()
        )
        let setupExpectation = expectation(
            description: "migrated v2 wallets are resolved"
        )
        selectedWalletSettings.setup(
            runningCompletionIn: .main
        ) { result in
            do {
                XCTAssertNotNil(try result.get())
            } catch {
                XCTFail("Migrated v2 wallet setup failed: \(error)")
            }
            setupExpectation.fulfill()
        }
        wait(
            for: [setupExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(selectedWalletSettings.storeState, .ready)
        let helper = StartViewHelper(
            keystore: keystore,
            selectedWalletSettings: selectedWalletSettings,
            userDefaultsStorage: InMemorySettingsManager()
        )
        guard case .pin = helper.startView(onboardingConfig: nil) else {
            return XCTFail(
                "A nonempty migrated v2 store with a PIN must route to authentication"
            )
        }
        XCTAssertEqual(
            try keystore.fetchKey(for: fearless.KeystoreTag.pincode.rawValue),
            pincode
        )
    }

    func testPerformMigration_whenIntermediateV3StoreDropsWallet_thenPerHopCountFailsClosedAndRetryPreservesFixture() throws {
        let sourceModel = try model(for: .version2)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertVersion2WalletFixture(
                in: context,
                model: sourceModel
            )
        }
        let sourceChecksum = try metadataChecksum(at: storeURL)
        let sourceFiles = try durableStoreSnapshot(at: storeURL)
        let pincode = Data("135790".utf8)
        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            pincode,
            with: fearless.KeystoreTag.pincode.rawValue
        )
        var stagedMutationCount = 0
        let adversarialMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            stagedStoreWillValidate: { stagedURL, version in
                guard version == .version3 else {
                    return
                }

                stagedMutationCount += 1
                try self.executeSQLite(
                    "DELETE FROM ZCDMETAACCOUNT " +
                        "WHERE Z_PK = " +
                        "(SELECT MIN(Z_PK) FROM ZCDMETAACCOUNT)",
                    at: stagedURL
                )
            }
        )

        XCTAssertThrowsError(
            try adversarialMigrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(stagedMutationCount, 1)
        XCTAssertEqual(try metadataChecksum(at: storeURL), sourceChecksum)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            sourceFiles
        )
        XCTAssertEqual(
            try keystore.fetchKey(for: fearless.KeystoreTag.pincode.rawValue),
            pincode
        )

        let retryMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertTrue(try retryMigrator.performMigration())
        XCTAssertFalse(try retryMigrator.performMigration())
        XCTAssertEqual(
            try walletSnapshots(
                from: storeURL,
                model: model(for: .version14)
            ),
            version2WalletFixtureSnapshots()
        )
        XCTAssertEqual(
            try keystore.fetchKey(for: fearless.KeystoreTag.pincode.rawValue),
            pincode
        )
    }

    func testPerformMigration_whenIntermediateV3StoreDropsChainAccountButWalletCountIsUnchanged_thenPerHopIntegrityFailsClosed() throws {
        let sourceModel = try model(for: .version2)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertVersion2WalletFixture(
                in: context,
                model: sourceModel
            )
        }
        let sourceChecksum = try metadataChecksum(at: storeURL)
        let sourceFiles = try durableStoreSnapshot(at: storeURL)
        var stagedMutationCount = 0
        let adversarialMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            stagedStoreWillValidate: { stagedURL, version in
                guard version == .version3 else {
                    return
                }

                stagedMutationCount += 1
                try self.executeSQLite(
                    "DELETE FROM ZCDCHAINACCOUNT " +
                        "WHERE Z_PK = " +
                        "(SELECT MIN(Z_PK) FROM ZCDCHAINACCOUNT)",
                    at: stagedURL
                )
            }
        )

        XCTAssertThrowsError(
            try adversarialMigrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(stagedMutationCount, 1)
        XCTAssertEqual(try metadataChecksum(at: storeURL), sourceChecksum)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            sourceFiles
        )

        let retryMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertTrue(try retryMigrator.performMigration())
        XCTAssertEqual(
            try walletSnapshots(
                from: storeURL,
                model: model(for: .version14)
            ),
            version2WalletFixtureSnapshots()
        )
    }

    func testPerformMigration_whenIntermediateV3StoreMutatesWalletFieldWithoutChangingCount_thenPerHopIntegrityFailsClosed() throws {
        let sourceModel = try model(for: .version2)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertVersion2WalletFixture(
                in: context,
                model: sourceModel
            )
        }
        let sourceChecksum = try metadataChecksum(at: storeURL)
        let sourceFiles = try durableStoreSnapshot(at: storeURL)
        var stagedMutationCount = 0
        let adversarialMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            stagedStoreWillValidate: { stagedURL, version in
                guard version == .version3 else {
                    return
                }

                stagedMutationCount += 1
                try self.executeSQLite(
                    "UPDATE ZCDMETAACCOUNT " +
                        "SET ZNAME = 'adversarial-wallet-name' " +
                        "WHERE Z_PK = " +
                        "(SELECT MIN(Z_PK) FROM ZCDMETAACCOUNT)",
                    at: stagedURL
                )
            }
        )

        XCTAssertThrowsError(
            try adversarialMigrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(stagedMutationCount, 1)
        XCTAssertEqual(try metadataChecksum(at: storeURL), sourceChecksum)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            sourceFiles
        )

        let retryMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertTrue(try retryMigrator.performMigration())
        XCTAssertEqual(
            try walletSnapshots(
                from: storeURL,
                model: model(for: .version14)
            ),
            version2WalletFixtureSnapshots()
        )
    }

    func testMigration_whenLegacyFieldsAreIntentionallyDerived_thenPreservesExactAssetVisibilityAndNetworkFilterSemantics() throws {
        let visibilityURL = testDirectory.appendingPathComponent(
            "version9-asset-visibility.sqlite"
        )
        let visibilitySourceModel = try model(for: .version9)
        try createStore(
            at: visibilityURL,
            model: visibilitySourceModel
        ) { context in
            let wallet = try self.insertHistoricalWallet(
                metaId: "visibility-wallet",
                name: "Visibility Wallet",
                in: context,
                model: visibilitySourceModel
            )
            wallet.setValue(
                ["asset-b", "asset-a"] as NSArray,
                forKey: "assetIdsEnabled"
            )
        }

        let visibilityMigrator = UserStorageMigrator(
            targetVersion: .version10,
            storeURL: visibilityURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertTrue(try visibilityMigrator.performMigration())
        var migratedVisibility = [String: Bool]()
        try useStore(
            at: visibilityURL,
            model: model(for: .version10)
        ) { context in
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDAssetVisibility"
            )
            for visibility in try context.fetch(request) {
                let assetId = try XCTUnwrap(
                    visibility.value(forKey: "assetId") as? String
                )
                let hidden = try XCTUnwrap(
                    visibility.value(forKey: "hidden") as? NSNumber
                )
                migratedVisibility[assetId] = hidden.boolValue
            }
        }
        XCTAssertEqual(
            migratedVisibility,
            ["asset-a": true, "asset-b": true]
        )

        let filterURL = testDirectory.appendingPathComponent(
            "version11-network-filter.sqlite"
        )
        let filterSourceModel = try model(for: .version11)
        try createStore(
            at: filterURL,
            model: filterSourceModel
        ) { context in
            let wallet = try self.insertHistoricalWallet(
                metaId: "filter-wallet",
                name: "Filter Wallet",
                in: context,
                model: filterSourceModel
            )
            wallet.setValue(
                "polkadot-filter",
                forKey: "chainIdForFilter"
            )
        }

        let filterMigrator = UserStorageMigrator(
            targetVersion: .version12,
            storeURL: filterURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertTrue(try filterMigrator.performMigration())
        var migratedFilter: String?
        var migratedFavourites: [String]?
        try useStore(
            at: filterURL,
            model: model(for: .version12)
        ) { context in
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDMetaAccount"
            )
            let wallet = try XCTUnwrap(
                context.fetch(request).first
            )
            migratedFilter = wallet.value(
                forKey: "networkManagmentFilter"
            ) as? String
            migratedFavourites =
                try SafeTransformableValueReader.read(
                    from: wallet,
                    key: "favouriteChainIds"
                )
        }
        XCTAssertEqual(migratedFilter, "polkadot-filter")
        XCTAssertEqual(migratedFavourites, [])
    }

    func testMigration_whenIntentionalDerivedFieldsAreDroppedOrMutatedInStaging_thenSemanticIntegrityFailsClosed() throws {
        let visibilityURL = testDirectory.appendingPathComponent(
            "adversarial-version9-asset-visibility.sqlite"
        )
        let visibilitySourceModel = try model(for: .version9)
        try createStore(
            at: visibilityURL,
            model: visibilitySourceModel
        ) { context in
            let wallet = try self.insertHistoricalWallet(
                metaId: "visibility-wallet",
                name: "Visibility Wallet",
                in: context,
                model: visibilitySourceModel
            )
            wallet.setValue(
                ["asset-a", "asset-b"] as NSArray,
                forKey: "assetIdsEnabled"
            )
        }
        let visibilitySourceFiles =
            try durableStoreSnapshot(at: visibilityURL)
        let visibilityMigrator = UserStorageMigrator(
            targetVersion: .version10,
            storeURL: visibilityURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            stagedStoreWillValidate: { stagedURL, version in
                guard version == .version10 else {
                    return
                }

                try self.executeSQLite(
                    "DELETE FROM ZCDASSETVISIBILITY " +
                        "WHERE Z_PK = " +
                        "(SELECT MIN(Z_PK) " +
                        "FROM ZCDASSETVISIBILITY)",
                    at: stagedURL
                )
            }
        )
        XCTAssertThrowsError(
            try visibilityMigrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            try durableStoreSnapshot(at: visibilityURL),
            visibilitySourceFiles
        )

        let filterURL = testDirectory.appendingPathComponent(
            "adversarial-version11-network-filter.sqlite"
        )
        let filterSourceModel = try model(for: .version11)
        try createStore(
            at: filterURL,
            model: filterSourceModel
        ) { context in
            let wallet = try self.insertHistoricalWallet(
                metaId: "filter-wallet",
                name: "Filter Wallet",
                in: context,
                model: filterSourceModel
            )
            wallet.setValue(
                "polkadot-filter",
                forKey: "chainIdForFilter"
            )
        }
        let filterSourceFiles =
            try durableStoreSnapshot(at: filterURL)
        let filterMigrator = UserStorageMigrator(
            targetVersion: .version12,
            storeURL: filterURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            stagedStoreWillValidate: { stagedURL, version in
                guard version == .version12 else {
                    return
                }

                try self.executeSQLite(
                    "UPDATE ZCDMETAACCOUNT SET " +
                        "ZNETWORKMANAGMENTFILTER = " +
                        "'adversarial-filter'",
                    at: stagedURL
                )
            }
        )
        XCTAssertThrowsError(
            try filterMigrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            try durableStoreSnapshot(at: filterURL),
            filterSourceFiles
        )
    }

    func testMigration_whenV1ToV2DropsDestinationAccount_thenLegacyAccountSemanticIntegrityFailsClosed() throws {
        let sourceModel = try model(for: .version1)
        let addressFactory = SS58AddressFactory()
        let addresses = try [UInt8(0x81), UInt8(0x82)].map {
            try addressFactory.address(
                fromAccountId: Data(repeating: $0, count: 32),
                type: 42
            )
        }
        try createStore(at: storeURL, model: sourceModel) { context in
            let entity = try XCTUnwrap(
                sourceModel.entitiesByName["CDAccountItem"]
            )
            for (index, address) in addresses.enumerated() {
                let account = NSManagedObject(
                    entity: entity,
                    insertInto: context
                )
                account.setValue(address, forKey: "identifier")
                account.setValue(
                    "Legacy \(index)",
                    forKey: "username"
                )
                account.setValue(
                    Data(repeating: UInt8(0x91 + index), count: 32),
                    forKey: "publicKey"
                )
                account.setValue(Int16(0), forKey: "cryptoType")
            }
        }
        let sourceFiles = try durableStoreSnapshot(at: storeURL)
        var stagedMutationCount = 0
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            stagedStoreWillValidate: { stagedURL, version in
                guard version == .version2 else {
                    return
                }

                stagedMutationCount += 1
                try self.executeSQLite(
                    "DELETE FROM ZCDMETAACCOUNT " +
                        "WHERE Z_PK = " +
                        "(SELECT MIN(Z_PK) FROM ZCDMETAACCOUNT)",
                    at: stagedURL
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) {
            error in

            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(stagedMutationCount, 1)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            sourceFiles
        )
    }

    func testMigration_whenLegacyEcosystemStore_thenPreservesWalletTonAssetAndChainData() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }

        let migrator = makeMigrator()
        XCTAssertTrue(migrator.requiresMigration())

        try migrator.performMigration()

        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)

        let snapshots = try walletSnapshots(
            from: storeURL,
            model: model(for: .version14)
        )
        XCTAssertEqual(snapshots.count, 2)

        let regularWallet = try XCTUnwrap(
            snapshots.first { $0.metaId == "regular-wallet" }
        )
        XCTAssertEqual(regularWallet.name, "Regular Wallet")
        XCTAssertEqual(regularWallet.substrateAccountId, hex(byte: 0x11, count: 32))
        XCTAssertEqual(regularWallet.substratePublicKey, Data(repeating: 0x12, count: 32))
        XCTAssertEqual(regularWallet.tonAddress, Data(repeating: 0x13, count: 36))
        XCTAssertEqual(regularWallet.tonPublicKey, Data(repeating: 0x14, count: 32))
        XCTAssertEqual(regularWallet.tonContractVersion, "v4R2")
        XCTAssertEqual(
            regularWallet.assetsVisibility,
            ["polkadot-0": false, "kusama-0": true]
        )
        XCTAssertEqual(
            regularWallet.chainAccounts,
            [
                ChainSnapshot(
                    chainId: "ethereum-chain",
                    accountId: hex(byte: 0x31, count: 20),
                    publicKey: Data(repeating: 0x32, count: 33),
                    cryptoType: 2,
                    ecosystem: UniversalWalletEcosystem.evm.rawValue
                ),
                ChainSnapshot(
                    chainId: "substrate-chain",
                    accountId: hex(byte: 0x21, count: 32),
                    publicKey: Data(repeating: 0x22, count: 32),
                    cryptoType: 1,
                    ecosystem: "substrate"
                )
            ]
        )

        let tonOnlyWallet = try XCTUnwrap(
            snapshots.first { $0.metaId == "ton-only-wallet" }
        )
        XCTAssertEqual(tonOnlyWallet.name, "TON Only Wallet")
        XCTAssertNil(tonOnlyWallet.substrateAccountId)
        XCTAssertNil(tonOnlyWallet.substratePublicKey)
        XCTAssertEqual(tonOnlyWallet.tonAddress, Data(repeating: 0x41, count: 36))
        XCTAssertEqual(tonOnlyWallet.tonPublicKey, Data(repeating: 0x42, count: 32))
        XCTAssertEqual(tonOnlyWallet.tonContractVersion, "v5R1")
        XCTAssertTrue(tonOnlyWallet.assetsVisibility.isEmpty)
        XCTAssertTrue(tonOnlyWallet.chainAccounts.isEmpty)
    }

    func testMigration_whenPublicV11Store_thenPreservesWalletAssetAndEthereumChainData() throws {
        let publicModel = try model(for: .version12)
        try createStore(at: storeURL, model: publicModel) { context in
            self.insertCurrentWallet(in: context, model: publicModel)
            let walletRequest = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            let wallet = try XCTUnwrap(context.fetch(walletRequest).first)

            try self.insertAssetVisibility(
                assetId: "ethereum-mainnet-eth",
                hidden: true,
                wallet: wallet,
                in: context,
                model: publicModel
            )
            try self.insertPublicChainAccount(
                wallet: wallet,
                in: context,
                model: publicModel
            )
        }

        let migrator = makeMigrator()
        XCTAssertTrue(migrator.requiresMigration())

        try migrator.performMigration()

        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)

        let currentModel = try model(for: .version14)
        let snapshots = try walletSnapshots(from: storeURL, model: currentModel)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.metaId, "current-wallet")
        XCTAssertEqual(snapshots.first?.name, "Current Wallet")
        XCTAssertEqual(
            snapshots.first?.assetsVisibility,
            ["ethereum-mainnet-eth": true]
        )

        try useStore(at: storeURL, model: currentModel) { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDChainAccount")
            let chainAccount = try XCTUnwrap(context.fetch(request).first)

            XCTAssertEqual(chainAccount.value(forKey: "chainId") as? String, "ethereum-mainnet")
            XCTAssertEqual(
                (chainAccount.value(forKey: "ethereumBased") as? NSNumber)?.boolValue,
                true
            )
            XCTAssertNil(chainAccount.value(forKey: "ecosystem"))
        }
    }

    func testMigration_whenV11OrLegacyV12PreferenceArchiveIsInvalid_thenDefaultsOnlyDamagedField() throws {
        let preferences = [
            (key: "assetFilterOptions", column: "ZASSETFILTEROPTIONS"),
            (key: "assetKeysOrder", column: "ZASSETKEYSORDER"),
            (key: "favouriteChainIds", column: "ZFAVOURITECHAINIDS"),
            (key: "unusedChainIds", column: "ZUNUSEDCHAINIDS")
        ]
        let expectedValues: [String: [String]] = [
            "assetFilterOptions": ["filter-option"],
            "assetKeysOrder": ["asset-order"],
            "favouriteChainIds": ["favourite-chain"],
            "unusedChainIds": ["unused-chain"]
        ]

        for sourceVersion in [
            UserStorageVersion.version12,
            UserStorageVersion.version13
        ] {
            for preference in preferences {
                let caseURL = testDirectory.appendingPathComponent(
                    "\(sourceVersion.rawValue)-\(preference.key).sqlite"
                )
                let sourceModel = try model(for: sourceVersion)
                try createStore(at: caseURL, model: sourceModel) { context in
                    self.insertCurrentWallet(
                        in: context,
                        model: sourceModel
                    )
                    let request = NSFetchRequest<NSManagedObject>(
                        entityName: "CDMetaAccount"
                    )
                    let wallet = try XCTUnwrap(context.fetch(request).first)
                    for (key, value) in expectedValues {
                        wallet.setValue(value as NSArray, forKey: key)
                    }
                }

                try executeSQLite(
                    "UPDATE ZCDMETAACCOUNT " +
                        "SET \(preference.column) = X'00FF00'",
                    at: caseURL
                )

                try makeMigrator(storeURL: caseURL).performMigration()

                XCTAssertEqual(
                    try metadataChecksum(at: caseURL),
                    currentChecksum,
                    "\(sourceVersion.rawValue).\(preference.key)"
                )

                try useStore(
                    at: caseURL,
                    model: model(for: .version14)
                ) { context in
                    let request = NSFetchRequest<NSManagedObject>(
                        entityName: "CDMetaAccount"
                    )
                    let wallet = try XCTUnwrap(context.fetch(request).first)
                    XCTAssertEqual(
                        wallet.value(forKey: "metaId") as? String,
                        "current-wallet"
                    )
                    XCTAssertEqual(
                        wallet.value(forKey: "name") as? String,
                        "Current Wallet"
                    )
                    XCTAssertEqual(
                        wallet.value(forKey: "substrateAccountId") as? String,
                        self.hex(byte: 0x51, count: 32)
                    )
                    XCTAssertEqual(
                        wallet.value(forKey: "substratePublicKey") as? Data,
                        Data(repeating: 0x52, count: 32)
                    )

                    for (key, expectedValue) in expectedValues {
                        let actualValue =
                            wallet.value(forKey: key) as? [String]
                        XCTAssertEqual(
                            actualValue,
                            key == preference.key ? [] : expectedValue,
                            "\(sourceVersion.rawValue).\(preference.key).\(key)"
                        )
                    }
                }
            }
        }
    }

    func testMigration_whenPreferenceArchiveHasWrongDecodedType_thenDefaultsOnlyDamagedField() throws {
        let expectedValues = preferenceFixtureValues()
        let preferences = [
            (key: "assetFilterOptions", column: "ZASSETFILTEROPTIONS"),
            (key: "assetKeysOrder", column: "ZASSETKEYSORDER"),
            (key: "favouriteChainIds", column: "ZFAVOURITECHAINIDS"),
            (key: "unusedChainIds", column: "ZUNUSEDCHAINIDS")
        ]
        let wrongTypeArchive = try NSKeyedArchiver.archivedData(
            withRootObject: NSString(string: "not-a-string-array"),
            requiringSecureCoding: true
        )
        let archiveHex = wrongTypeArchive.map {
            String(format: "%02X", $0)
        }.joined()

        for sourceVersion in [
            UserStorageVersion.version12,
            UserStorageVersion.version13
        ] {
            for preference in preferences {
                let caseURL = testDirectory.appendingPathComponent(
                    "\(sourceVersion.rawValue)-wrong-type-" +
                        "\(preference.key).sqlite"
                )
                try createPreferenceFixture(
                    at: caseURL,
                    sourceVersion: sourceVersion,
                    values: expectedValues
                )
                try executeSQLite(
                    "UPDATE ZCDMETAACCOUNT " +
                        "SET \(preference.column) = X'\(archiveHex)'",
                    at: caseURL
                )

                try makeMigrator(storeURL: caseURL).performMigration()

                var expectedMigratedValues = expectedValues
                expectedMigratedValues[preference.key] = []
                XCTAssertEqual(
                    try migratedPreferenceValues(at: caseURL),
                    expectedMigratedValues,
                    "\(sourceVersion.rawValue).\(preference.key)"
                )
            }
        }
    }

    func testMigration_whenPreferenceArchivesAreValid_thenPreservesEveryValue() throws {
        let expectedValues = preferenceFixtureValues()

        for sourceVersion in [
            UserStorageVersion.version12,
            UserStorageVersion.version13
        ] {
            let caseURL = testDirectory.appendingPathComponent(
                "\(sourceVersion.rawValue)-valid-preferences.sqlite"
            )
            try createPreferenceFixture(
                at: caseURL,
                sourceVersion: sourceVersion,
                values: expectedValues
            )

            try makeMigrator(storeURL: caseURL).performMigration()

            XCTAssertEqual(
                try migratedPreferenceValues(at: caseURL),
                expectedValues
            )
        }
    }

    func testRawArchivePreflight_whenValuesCrossByteBoundary_thenRepairsOnlyOversizedArchivesAndIsIdempotent() throws {
        let sourceModel = try model(for: .version13)
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version13,
            values: preferenceFixtureValues()
        )
        let boundaryArchive = try NSKeyedArchiver.archivedData(
            withRootObject: ["boundary"] as NSArray,
            requiringSecureCoding: true
        )
        let oversizedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: [
                String(repeating: "x", count: 4096)
            ] as NSArray,
            requiringSecureCoding: true
        )
        XCTAssertGreaterThan(
            oversizedArchive.count,
            boundaryArchive.count
        )
        try updateSQLiteBlob(
            boundaryArchive,
            column: "ZASSETFILTEROPTIONS",
            at: storeURL
        )
        try updateSQLiteBlob(
            oversizedArchive,
            column: "ZASSETKEYSORDER",
            at: storeURL
        )
        try updateSQLiteBlob(
            oversizedArchive,
            column: "ZFAVOURITECHAINIDS",
            at: storeURL
        )

        let entity = try XCTUnwrap(
            sourceModel.entitiesByName["CDMetaAccount"]
        )
        let columns = try [
            "assetFilterOptions",
            "assetKeysOrder",
            "favouriteChainIds"
        ].map { key in
            let attribute = try XCTUnwrap(
                entity.attributesByName[key]
            )
            return SQLiteTransformableArchiveColumn(
                entityName: "CDMetaAccount",
                attributeName: key,
                isOptional: attribute.isOptional,
                valueTransformerName:
                attribute.valueTransformerName
            )
        }

        XCTAssertEqual(
            try SQLiteTransformableArchivePreflight
                .repairOversizedArchives(
                    at: storeURL,
                    columns: columns,
                    maximumArchiveByteCount:
                    boundaryArchive.count
                ),
            2
        )
        XCTAssertEqual(
            try SQLiteTransformableArchivePreflight
                .repairOversizedArchives(
                    at: storeURL,
                    columns: columns,
                    maximumArchiveByteCount:
                    boundaryArchive.count
                ),
            0
        )

        try useStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDMetaAccount"
            )
            let wallet = try XCTUnwrap(
                context.fetch(request).first
            )
            XCTAssertEqual(
                wallet.value(
                    forKey: "assetFilterOptions"
                ) as? [String],
                ["boundary"]
            )
            XCTAssertNil(
                wallet.value(
                    forKey: "assetKeysOrder"
                )
            )
            XCTAssertEqual(
                wallet.value(
                    forKey: "favouriteChainIds"
                ) as? [String],
                []
            )
        }
    }

    func testRawArchivePreflight_whenRequiredReplacementExceedsLimit_thenRollsBackWithoutMutation() throws {
        let sourceModel = try model(for: .version13)
        let oversizedValue =
            String(repeating: "x", count: 4096)
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version13,
            values: preferenceFixtureValues()
        )
        let oversizedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: [oversizedValue] as NSArray,
            requiringSecureCoding: true
        )
        try updateSQLiteBlob(
            oversizedArchive,
            column: "ZFAVOURITECHAINIDS",
            at: storeURL
        )

        let entity = try XCTUnwrap(
            sourceModel.entitiesByName["CDMetaAccount"]
        )
        let attribute = try XCTUnwrap(
            entity.attributesByName["favouriteChainIds"]
        )
        XCTAssertFalse(attribute.isOptional)
        let column = SQLiteTransformableArchiveColumn(
            entityName: "CDMetaAccount",
            attributeName: "favouriteChainIds",
            isOptional: attribute.isOptional,
            valueTransformerName:
            attribute.valueTransformerName
        )

        XCTAssertThrowsError(
            try SQLiteTransformableArchivePreflight
                .repairOversizedArchives(
                    at: storeURL,
                    columns: [column],
                    maximumArchiveByteCount: 1
                )
        ) { error in
            XCTAssertEqual(
                error as?
                    SQLiteTransformableArchiveRepairError,
                .invalidLimit
            )
        }

        try useStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDMetaAccount"
            )
            let wallet = try XCTUnwrap(
                context.fetch(request).first
            )
            XCTAssertEqual(
                wallet.value(
                    forKey: "favouriteChainIds"
                ) as? [String],
                [oversizedValue]
            )
        }
    }

    func testMigration_whenRawPreferenceArchiveExceedsProductionLimit_thenRepairsBeforeCoreDataDecode() throws {
        var expectedValues = preferenceFixtureValues()
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version13,
            values: expectedValues
        )
        let oversizedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: [
                String(
                    repeating: "x",
                    count: 1 * 1024 * 1024
                )
            ] as NSArray,
            requiringSecureCoding: true
        )
        XCTAssertGreaterThan(
            oversizedArchive.count,
            1 * 1024 * 1024
        )
        try updateSQLiteBlob(
            oversizedArchive,
            column: "ZASSETKEYSORDER",
            at: storeURL
        )

        try makeMigrator().performMigration()

        expectedValues.removeValue(
            forKey: "assetKeysOrder"
        )
        XCTAssertEqual(
            try migratedPreferenceValues(at: storeURL),
            expectedValues
        )
    }

    func testMigration_whenDecodedPreferenceLimitsAreCrossed_thenRepairsOverLimitAndPreservesExactBoundaries() throws {
        let boundaryValue = String(repeating: "b", count: 32)
        let overByteValue = String(repeating: "o", count: 40)
        let expectedValues: [String: [String]] = [
            "assetFilterOptions": [
                boundaryValue,
                boundaryValue
            ],
            "assetKeysOrder": ["one", "two", "three"],
            "favouriteChainIds": ["one", "two"],
            "unusedChainIds": [
                overByteValue,
                overByteValue
            ]
        ]
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version13,
            values: expectedValues
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 64,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 2
            )
        )

        try migrator.performMigration()

        XCTAssertEqual(
            try migratedPreferenceValues(at: storeURL),
            [
                "assetFilterOptions": [
                    boundaryValue,
                    boundaryValue
                ],
                "assetKeysOrder": [],
                "favouriteChainIds": ["one", "two"],
                "unusedChainIds": []
            ]
        )
    }

    func testMigration_whenCurrentVersionRequiredArchiveExceedsRawLimit_thenAtomicallyRepairsAndSubsequentRunIsNoOp() throws {
        var expectedValues = preferenceFixtureValues()
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version14,
            values: expectedValues
        )
        let oversizedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: [
                String(
                    repeating: "x",
                    count: 1 * 1024 * 1024
                )
            ] as NSArray,
            requiringSecureCoding: true
        )
        try updateSQLiteBlob(
            oversizedArchive,
            column: "ZFAVOURITECHAINIDS",
            at: storeURL
        )
        let damagedStoreSnapshot =
            try durableStoreSnapshot(at: storeURL)
        var replacementCount = 0
        var stagedValidationCount = 0
        var keystoreMigratorCreated = false
        var settingsMigratorCreated = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { targetURL, sourceURL in
                replacementCount += 1
                try NSPersistentStoreCoordinator.replaceStore(
                    at: targetURL,
                    withStoreAt: sourceURL
                )
            },
            keystoreMigratorFactory: {
                source,
                    destination,
                    keystore in

                keystoreMigratorCreated = true
                return KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore
                )
            },
            settingsMigratorFactory: {
                source,
                    destination,
                    settings in

                settingsMigratorCreated = true
                return SettingsMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    settings: settings
                )
            },
            stagedStoreWillValidate: { _, version in
                XCTAssertEqual(version, .version14)
                stagedValidationCount += 1
            }
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            damagedStoreSnapshot
        )
        XCTAssertTrue(try migrator.performMigration())
        expectedValues["favouriteChainIds"] = []
        XCTAssertEqual(
            try migratedPreferenceValues(at: storeURL),
            expectedValues
        )
        XCTAssertFalse(try migrator.performMigration())
        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(replacementCount, 1)
        XCTAssertEqual(stagedValidationCount, 1)
        XCTAssertFalse(keystoreMigratorCreated)
        XCTAssertFalse(settingsMigratorCreated)
    }

    func testMigration_whenCurrentVersionOptionalArchiveHasWrongSQLiteType_thenAtomicallyRepairsToNullAndSubsequentRunIsNoOp() throws {
        var expectedValues = preferenceFixtureValues()
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version14,
            values: expectedValues
        )
        try executeSQLite(
            """
            UPDATE ZCDMETAACCOUNT
            SET ZASSETKEYSORDER = 'not-a-blob'
            """,
            at: storeURL
        )
        let damagedStoreSnapshot =
            try durableStoreSnapshot(at: storeURL)
        var replacementCount = 0
        var keystoreMigratorCreated = false
        var settingsMigratorCreated = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { targetURL, sourceURL in
                replacementCount += 1
                try NSPersistentStoreCoordinator.replaceStore(
                    at: targetURL,
                    withStoreAt: sourceURL
                )
            },
            keystoreMigratorFactory: {
                source,
                    destination,
                    keystore in

                keystoreMigratorCreated = true
                return KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore
                )
            },
            settingsMigratorFactory: {
                source,
                    destination,
                    settings in

                settingsMigratorCreated = true
                return SettingsMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    settings: settings
                )
            }
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            damagedStoreSnapshot
        )
        XCTAssertTrue(try migrator.performMigration())
        expectedValues.removeValue(
            forKey: "assetKeysOrder"
        )
        XCTAssertEqual(
            try migratedPreferenceValues(at: storeURL),
            expectedValues
        )
        XCTAssertFalse(try migrator.performMigration())
        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(replacementCount, 1)
        XCTAssertFalse(keystoreMigratorCreated)
        XCTAssertFalse(settingsMigratorCreated)
    }

    func testMigration_whenCurrentVersionDecodedPreferenceExceedsLimit_thenCountsRepairAndSubsequentRunIsNoOp() throws {
        var expectedValues = preferenceFixtureValues()
        expectedValues["assetKeysOrder"] = ["one", "two"]
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version14,
            values: expectedValues
        )
        var replacementCount = 0
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 1
            ),
            storeReplacer: { targetURL, sourceURL in
                replacementCount += 1
                try NSPersistentStoreCoordinator.replaceStore(
                    at: targetURL,
                    withStoreAt: sourceURL
                )
            }
        )

        XCTAssertTrue(try migrator.performMigration())
        expectedValues["assetKeysOrder"] = []
        XCTAssertEqual(
            try migratedPreferenceValues(at: storeURL),
            expectedValues
        )
        XCTAssertFalse(try migrator.performMigration())
        XCTAssertEqual(replacementCount, 1)
    }

    func testMigration_whenCurrentVersionRepairFitsCopyLimitButFinalBackupCapacityIsInsufficient_thenPreservesLiveStore() throws {
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version14,
            values: preferenceFixtureValues()
        )
        try executeSQLite(
            """
            UPDATE ZCDMETAACCOUNT
            SET ZASSETKEYSORDER = 'not-a-blob'
            """,
            at: storeURL
        )
        let before = try durableStoreSnapshot(at: storeURL)
        var capacityInspectionCount = 0
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            privateSourceCopyLimits:
            SQLiteStoreFamilyCopyLimits(
                maximumFamilyByteCount: 512 * 1024 * 1024,
                minimumFreeStorageReserveByteCount: 17
            ),
            privateSourceAvailableCapacityProvider: { _ in
                capacityInspectionCount += 1
                return capacityInspectionCount == 1
                    ? UInt64.max
                    : 0
            },
            storeReplacer: { _, _ in
                replacementAttempted = true
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let capacityError =
                error as? CrashConsistentStoreReplacementError,
                case let .insufficientStorageCapacity(
                    requiredByteCount,
                    availableByteCount
                ) = capacityError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertGreaterThan(requiredByteCount, 17)
            XCTAssertEqual(availableByteCount, 0)
        }
        XCTAssertEqual(capacityInspectionCount, 2)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMigration_whenCurrentVersionRepairValidationHookDropsWallet_thenRejectsMutatedBaselineBeforeReplacement() throws {
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version14,
            values: preferenceFixtureValues()
        )
        try executeSQLite(
            """
            UPDATE ZCDMETAACCOUNT
            SET ZASSETKEYSORDER = 'not-a-blob'
            """,
            at: storeURL
        )
        let before = try durableStoreSnapshot(at: storeURL)
        var stagedMutationAttempted = false
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            stagedStoreWillValidate: { stagedURL, version in
                XCTAssertEqual(version, .version14)
                stagedMutationAttempted = true
                try self.executeSQLite(
                    "DELETE FROM ZCDMETAACCOUNT",
                    at: stagedURL
                )
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed =
                migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(stagedMutationAttempted)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testRelationshipCountPreflight_whenRelationshipIsFaulted_thenCountsWithoutMaterializingIt() throws {
        let sourceModel = try model(for: .version13)
        try createStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        let migrator = makeMigrator()

        try useStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDMetaAccount"
            )
            request.predicate = NSPredicate(
                format: "metaId == %@",
                "regular-wallet"
            )
            let wallet = try XCTUnwrap(
                context.fetch(request).first
            )
            XCTAssertTrue(
                wallet.hasFault(
                    forRelationshipNamed: "chainAccounts"
                )
            )

            XCTAssertEqual(
                try migrator
                    .preflightRelationshipDestinationCount(
                        for: wallet,
                        relationshipName: "chainAccounts"
                    ),
                2
            )
            XCTAssertTrue(
                wallet.hasFault(
                    forRelationshipNamed: "chainAccounts"
                )
            )
        }
    }

    func testRelationshipAggregateCounter_whenCountReachesExactBoundary_thenAcceptsIt() throws {
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10,
                maximumTransformableElements: 4_096,
                maximumRelationshipDestinationsAcrossStore: 3
            )
        )
        var total = 1

        try migrator.accumulateRelationshipDestinationCount(
            2,
            total: &total
        )

        XCTAssertEqual(total, 3)
    }

    func testRelationshipAggregateCounter_whenLimitOrIntegerRangeIsExceeded_thenFailsWithoutChangingTotal() throws {
        let boundedMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10,
                maximumTransformableElements: 4_096,
                maximumRelationshipDestinationsAcrossStore: 3
            )
        )
        var boundedTotal = 3

        XCTAssertThrowsError(
            try boundedMigrator
                .accumulateRelationshipDestinationCount(
                    1,
                    total: &boundedTotal
                )
        )
        XCTAssertEqual(boundedTotal, 3)

        let overflowMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10,
                maximumTransformableElements: 4_096,
                maximumRelationshipDestinationsAcrossStore:
                Int.max
            )
        )
        var overflowTotal = Int.max

        XCTAssertThrowsError(
            try overflowMigrator
                .accumulateRelationshipDestinationCount(
                    1,
                    total: &overflowTotal
                )
        )
        XCTAssertEqual(overflowTotal, Int.max)
    }

    func testMigration_whenAggregateRelationshipDestinationsExceedStoreLimit_thenFailsBeforeStoreReplacement() throws {
        let sourceModel = try model(for: .version13)
        try createStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 4_096,
                maximumRelationshipDestinationsAcrossStore: 1
            ),
            storeReplacer: { _, _ in
                replacementAttempted = true
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed =
                migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMigration_whenRelationshipExceedsDestinationLimit_thenFailsBeforeStoreReplacement() throws {
        let sourceModel = try model(for: .version13)
        try createStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        let before = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 1,
                maximumTransformableElements: 4_096
            ),
            storeReplacer: { _, _ in
                replacementAttempted = true
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed =
                migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMigration_whenVersion1AccountRowLimitIsExceeded_thenFailsBeforeKeyOrStoreReplacement() throws {
        let sourceModel = try model(for: .version1)
        try createStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            let entity = try XCTUnwrap(
                sourceModel.entitiesByName["CDAccountItem"]
            )
            for index in 0 ..< 2 {
                let account = NSManagedObject(
                    entity: entity,
                    insertInto: context
                )
                account.setValue(
                    "legacy-\(index)",
                    forKey: "identifier"
                )
            }
        }
        let before = try durableStoreSnapshot(at: storeURL)
        var keystoreMigratorCreated = false
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 1,
                maximumRowsAcrossStore: 1,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 4_096
            ),
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            keystoreMigratorFactory: {
                source,
                    destination,
                    keystore in

                keystoreMigratorCreated = true
                return KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore
                )
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .privateSourceRepairFailed =
                migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(keystoreMigratorCreated)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMigration_whenVersion1RowsExceedKeystoreProductionCap_thenFailsBeforeMigrationPolicyOrKeyStaging() throws {
        let sourceModel = try model(for: .version1)
        let productionLimit =
            KeystoreMigrationResourceLimits.production
                .maximumLegacyAccountRows
        try createStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            let entity = try XCTUnwrap(
                sourceModel.entitiesByName["CDAccountItem"]
            )
            for index in 0 ... productionLimit {
                let account = NSManagedObject(
                    entity: entity,
                    insertInto: context
                )
                account.setValue(
                    "legacy-\(index)",
                    forKey: "identifier"
                )
            }
        }
        let before = try durableStoreSnapshot(at: storeURL)
        var keystoreMigratorCreated = false
        var stagedStoreReachedValidation = false
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            keystoreMigratorFactory: {
                source,
                    destination,
                    keystore in

                keystoreMigratorCreated = true
                return KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore
                )
            },
            stagedStoreWillValidate: { _, _ in
                stagedStoreReachedValidation = true
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .privateSourceRepairFailed =
                migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(keystoreMigratorCreated)
        XCTAssertFalse(stagedStoreReachedValidation)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMigration_whenVersion1SourceFamilyExceedsCopyLimit_thenFailsBeforeCapacityKeyOrStoreReplacement() throws {
        let sourceModel = try model(for: .version1)
        try createStore(
            at: storeURL,
            model: sourceModel
        ) { context in
            let entity = try XCTUnwrap(
                sourceModel.entitiesByName["CDAccountItem"]
            )
            let account = NSManagedObject(
                entity: entity,
                insertInto: context
            )
            account.setValue(
                "legacy",
                forKey: "identifier"
            )
        }
        let before = try durableStoreSnapshot(at: storeURL)
        var capacityInspected = false
        var keystoreMigratorCreated = false
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            privateSourceCopyLimits:
            SQLiteStoreFamilyCopyLimits(
                maximumFamilyByteCount: 1,
                minimumFreeStorageReserveByteCount: 0
            ),
            privateSourceAvailableCapacityProvider: { _ in
                capacityInspected = true
                return UInt64.max
            },
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            keystoreMigratorFactory: {
                source,
                    destination,
                    keystore in

                keystoreMigratorCreated = true
                return KeystoreMigrator(
                    sourceVersion: source,
                    destinationVersion: destination,
                    keystore: keystore
                )
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let copyError =
                error as? CrashConsistentStoreReplacementError,
                case let .storeFamilyTooLarge(
                    actualByteCount,
                    maximumByteCount
                ) = copyError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertGreaterThan(actualByteCount, 1)
            XCTAssertEqual(maximumByteCount, 1)
        }
        XCTAssertFalse(capacityInspected)
        XCTAssertFalse(keystoreMigratorCreated)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMigration_whenPrivateRepairSucceedsButReplacementFails_thenOnlyStagedFieldChangesAndSourceRemainsByteIdentical() throws {
        let expectedValues = preferenceFixtureValues()
        try createPreferenceFixture(
            at: storeURL,
            sourceVersion: .version13,
            values: expectedValues
        )
        try executeSQLite(
            "UPDATE ZCDMETAACCOUNT " +
                "SET ZASSETKEYSORDER = X'00FF00'",
            at: storeURL
        )
        let originalDurableFiles = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false

        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, stagedURL in
                replacementAttempted = true
                var expectedStagedValues = expectedValues
                expectedStagedValues["assetKeysOrder"] = []
                XCTAssertEqual(
                    try self.migratedPreferenceValues(at: stagedURL),
                    expectedStagedValues
                )
                throw UserStorageCommitTestError
                    .storeReplacementFailed
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            XCTAssertEqual(
                error as? UserStorageCommitTestError,
                .storeReplacementFailed
            )
        }
        XCTAssertTrue(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            originalDurableFiles
        )
    }

    func testMigration_whenPrivateRepairRowCapIsExceeded_thenRejectsBeforePagingOrReplacement() throws {
        let sourceModel = try model(for: .version13)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        try executeSQLite(
            """
            UPDATE ZCDMETAACCOUNT
            SET ZASSETKEYSORDER = X'00FF00'
            """,
            at: storeURL
        )
        let before = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false
        var fetchedPages = [(Int, Int)]()
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 1,
                maximumRowsAcrossStore: 100,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 4_096
            ),
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            privateSourceObjectIDPageDidFetch: {
                fetchedPages.append(($0, $1))
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) {
            error in
            guard
                let migrationError =
                    error as? UserStorageMigrationError,
                case .privateSourceRepairFailed = migrationError
            else {
                return XCTFail(
                    "Expected privateSourceRepairFailed, got \(error)"
                )
            }
        }
        XCTAssertTrue(fetchedPages.isEmpty)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMigration_whenPrivateRepairRowsSpanSingleIDPages_thenEnumeratesEveryWalletExactlyOnce() throws {
        let sourceModel = try model(for: .version13)
        try createStore(at: storeURL, model: sourceModel) {
            context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        var fetchedPages = [(Int, Int)]()
        var integrityPages = [(Int, Int)]()
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 4_096
            ),
            privateSourceObjectIDPageDidFetch: {
                fetchedPages.append(($0, $1))
            },
            integrityObjectPageDidFetch: {
                integrityPages.append(($0, $1))
            }
        )

        try migrator.performMigration()

        XCTAssertEqual(fetchedPages.count, 2)
        XCTAssertTrue(
            fetchedPages.allSatisfy {
                $0.0 == 1 && $0.1 == 1
            }
        )
        XCTAssertFalse(integrityPages.isEmpty)
        XCTAssertTrue(
            integrityPages.allSatisfy {
                $0.0 == 1 && $0.1 == 1
            }
        )
        XCTAssertEqual(
            try walletSnapshots(
                from: storeURL,
                model: model(for: .version14)
            ).count,
            2
        )
    }

    func testPerformMigration_whenStagedStoreDropsChainAccount_thenRefusesReplacementAndLeavesSourceUnchanged() throws {
        let sourceModel = try model(for: .version13)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        let originalDurableFiles = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false
        var stagedMutationAttempted = false

        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            stagedStoreWillValidate: { stagedURL, version in
                XCTAssertEqual(version, .version14)
                stagedMutationAttempted = true
                try self.executeSQLite(
                    "DELETE FROM ZCDCHAINACCOUNT",
                    at: stagedURL
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(stagedMutationAttempted)
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            originalDurableFiles
        )
    }

    func testPerformMigration_whenIntegrityRowBudgetIsExceeded_thenFailsBeforeReplacementAndLeavesSourceUnchanged() throws {
        let sourceModel = try model(for: .version13)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        let originalDurableFiles = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 1,
                maximumRowsAcrossStore: 100,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 1 * 1024 * 1024,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 4_096
            ),
            storeReplacer: { _, _ in
                replacementAttempted = true
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? UserStorageMigrationError,
                case .privateSourceRepairFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            originalDurableFiles
        )
    }

    func testPerformMigration_whenCanonicalIdentityByteBudgetIsExceeded_thenFailsBeforeReplacementAndLeavesSourceUnchanged() throws {
        let sourceModel = try model(for: .version13)
        try createStore(at: storeURL, model: sourceModel) { context in
            try self.insertLegacyWallets(
                in: context,
                model: sourceModel
            )
        }
        let originalDurableFiles = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            integrityValidationLimits:
            UserStorageIntegrityValidationLimits(
                maximumRowsPerEntity: 100,
                maximumRowsAcrossStore: 1_000,
                fetchBatchSize: 1,
                maximumCanonicalRowBytes: 32,
                maximumAttributeBytes: 256 * 1024,
                maximumRelationshipDestinations: 10_000,
                maximumTransformableElements: 4_096
            ),
            storeReplacer: { _, _ in
                replacementAttempted = true
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                let migrationError =
                    error as? UserStorageMigrationError,
                case .stagedStoreValidationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            originalDurableFiles
        )
    }

    func testPerformMigration_whenStagedStoreMutatesSameCountGlobalContentOrRelationships_thenRefusesReplacementAndLeavesSourceUnchanged() throws {
        let reorderedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: ["asset-b", "asset-a"] as NSArray,
            requiringSecureCoding: true
        ).map {
            String(format: "%02X", $0)
        }.joined()
        let substitutedArchive = try NSKeyedArchiver.archivedData(
            withRootObject: ["replacement-chain"] as NSArray,
            requiringSecureCoding: true
        ).map {
            String(format: "%02X", $0)
        }.joined()
        let mutations = [
            (
                name: "chain-settings",
                sql: "UPDATE ZCDCHAINSETTINGS " +
                    "SET ZISSUEMUTED = CASE ZISSUEMUTED " +
                    "WHEN 0 THEN 1 ELSE 0 END"
            ),
            (
                name: "custom-node",
                sql: "UPDATE ZCDCUSTOMCHAINNODE " +
                    "SET ZNAME = 'mutated-node'"
            ),
            (
                name: "orphan-membership",
                sql: "UPDATE ZCDMETAACCOUNT " +
                    "SET ZSELECTEDCURRENCY = " +
                    "(SELECT Z_PK FROM ZCDCURRENCY " +
                    "WHERE ZID = 'orphan-currency')"
            ),
            (
                name: "preference-reorder",
                sql: "UPDATE ZCDMETAACCOUNT SET " +
                    "ZASSETKEYSORDER = X'\(reorderedArchive)'"
            ),
            (
                name: "preference-substitution",
                sql: "UPDATE ZCDMETAACCOUNT SET " +
                    "ZFAVOURITECHAINIDS = X'\(substitutedArchive)'"
            )
        ]

        for sourceVersion in [
            UserStorageVersion.version12,
            UserStorageVersion.version13
        ] {
            for mutation in mutations {
                let caseURL = testDirectory.appendingPathComponent(
                    "\(sourceVersion.rawValue)-" +
                        "\(mutation.name).sqlite"
                )
                let sourceModel = try model(for: sourceVersion)
                try createStore(
                    at: caseURL,
                    model: sourceModel
                ) { context in
                    self.insertCurrentWallet(
                        in: context,
                        model: sourceModel
                    )

                    let walletRequest =
                        NSFetchRequest<NSManagedObject>(
                            entityName: "CDMetaAccount"
                        )
                    let wallet = try XCTUnwrap(
                        context.fetch(walletRequest).first
                    )
                    wallet.setValue(
                        ["filter-a", "filter-b"] as NSArray,
                        forKey: "assetFilterOptions"
                    )
                    wallet.setValue(
                        ["asset-a", "asset-b"] as NSArray,
                        forKey: "assetKeysOrder"
                    )
                    wallet.setValue(
                        ["favourite-a", "favourite-b"] as NSArray,
                        forKey: "favouriteChainIds"
                    )
                    wallet.setValue(
                        ["unused-a", "unused-b"] as NSArray,
                        forKey: "unusedChainIds"
                    )

                    let settingsEntity = try XCTUnwrap(
                        sourceModel.entitiesByName[
                            "CDChainSettings"
                        ]
                    )
                    let chainSettings = NSManagedObject(
                        entity: settingsEntity,
                        insertInto: context
                    )
                    chainSettings.setValue(
                        "settings-chain",
                        forKey: "chainId"
                    )
                    chainSettings.setValue(
                        true,
                        forKey: "autobalanced"
                    )
                    chainSettings.setValue(
                        false,
                        forKey: "issueMuted"
                    )

                    let nodeEntity = try XCTUnwrap(
                        sourceModel.entitiesByName[
                            "CDCustomChainNode"
                        ]
                    )
                    let node = NSManagedObject(
                        entity: nodeEntity,
                        insertInto: context
                    )
                    node.setValue(
                        "original-node",
                        forKey: "name"
                    )
                    node.setValue(
                        URL(string: "wss://node.example"),
                        forKey: "url"
                    )

                    let currencyEntity = try XCTUnwrap(
                        sourceModel.entitiesByName[
                            "CDCurrency"
                        ]
                    )
                    let orphan = NSManagedObject(
                        entity: currencyEntity,
                        insertInto: context
                    )
                    orphan.setValue(
                        "orphan-currency",
                        forKey: "id"
                    )
                    orphan.setValue(
                        "Orphan Currency",
                        forKey: "name"
                    )
                    orphan.setValue(
                        "ORP",
                        forKey: "symbol"
                    )
                }

                let originalDurableFiles =
                    try durableStoreSnapshot(at: caseURL)
                var replacementAttempted = false
                let migrator = UserStorageMigrator(
                    targetVersion: .version14,
                    storeURL: caseURL,
                    modelDirectory:
                    UserStorageParams.modelDirectory,
                    keystore: InMemoryKeychain(),
                    settings: InMemorySettingsManager(),
                    fileManager: .default,
                    modelBundle: appBundle,
                    storeReplacer: { _, _ in
                        replacementAttempted = true
                    },
                    stagedStoreWillValidate: {
                        stagedURL,
                            _ in

                        try self.executeSQLite(
                            mutation.sql,
                            at: stagedURL
                        )
                    }
                )

                XCTAssertThrowsError(
                    try migrator.performMigration()
                ) { error in
                    guard
                        let migrationError =
                        error as? UserStorageMigrationError,
                        case .stagedStoreValidationFailed =
                        migrationError
                    else {
                        return XCTFail(
                            "Unexpected error for " +
                                "\(sourceVersion.rawValue)." +
                                "\(mutation.name): \(error)"
                        )
                    }
                }
                XCTAssertFalse(
                    replacementAttempted,
                    "\(sourceVersion.rawValue)." +
                        "\(mutation.name)"
                )
                XCTAssertEqual(
                    try durableStoreSnapshot(at: caseURL),
                    originalDurableFiles,
                    "\(sourceVersion.rawValue)." +
                        "\(mutation.name)"
                )
            }
        }
    }

    func testPerformMigration_whenWALSourceReplacementFails_thenOriginalDurableFilesAreByteForByteUnchanged() throws {
        let sourceModel = try model(for: .version13)
        try createStore(at: storeURL, model: sourceModel) { context in
            self.insertCurrentWallet(in: context, model: sourceModel)
        }

        let database = try openSQLite(at: storeURL)
        defer {
            sqlite3_close(database)
        }
        try executeSQLite(
            "PRAGMA wal_autocheckpoint = 0; " +
                "UPDATE ZCDMETAACCOUNT SET ZNAME = 'WAL-only wallet';",
            database: database
        )

        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        XCTAssertTrue(FileManager.default.fileExists(atPath: walURL.path))
        XCTAssertFalse(try Data(contentsOf: walURL).isEmpty)
        let originalDurableFiles = try durableStoreSnapshot(at: storeURL)
        var replacementAttempted = false

        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, stagedURL in
                replacementAttempted = true
                try self.useStore(
                    at: stagedURL,
                    model: self.model(for: .version14)
                ) { context in
                    let request = NSFetchRequest<NSManagedObject>(
                        entityName: "CDMetaAccount"
                    )
                    let wallet = try XCTUnwrap(
                        context.fetch(request).first
                    )
                    XCTAssertEqual(
                        wallet.value(forKey: "name") as? String,
                        "WAL-only wallet"
                    )
                }
                throw UserStorageCommitTestError.storeReplacementFailed
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            XCTAssertEqual(
                error as? UserStorageCommitTestError,
                .storeReplacementFailed
            )
        }
        XCTAssertTrue(replacementAttempted)
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            originalDurableFiles
        )
    }

    func testCopyStoreFamily_whenRollbackJournalExists_thenCopiesRecoveryStateWithoutSourceShmOrMutation() throws {
        let sourceURL = testDirectory.appendingPathComponent(
            "CopyFamilySource.sqlite"
        )
        let destinationURL = testDirectory.appendingPathComponent(
            "CopyFamilyDestination.sqlite"
        )
        let sourceFiles = [
            sourceURL: Data([0x01, 0x02]),
            URL(fileURLWithPath: sourceURL.path + "-wal"):
                Data([0x03, 0x04]),
            URL(fileURLWithPath: sourceURL.path + "-journal"):
                Data([0x05, 0x06]),
            URL(fileURLWithPath: sourceURL.path + "-shm"):
                Data([0x07, 0x08])
        ]
        for (url, data) in sourceFiles {
            try data.write(to: url, options: .atomic)
        }
        let originalSourceFiles = try storeFamilySnapshot(at: sourceURL)

        try makeMigrator().copyStoreFamily(
            from: sourceURL,
            to: destinationURL
        )

        XCTAssertEqual(
            try Data(contentsOf: destinationURL),
            sourceFiles[sourceURL]
        )
        XCTAssertEqual(
            try Data(
                contentsOf: URL(
                    fileURLWithPath: destinationURL.path + "-wal"
                )
            ),
            sourceFiles[URL(fileURLWithPath: sourceURL.path + "-wal")]
        )
        XCTAssertEqual(
            try Data(
                contentsOf: URL(
                    fileURLWithPath: destinationURL.path + "-journal"
                )
            ),
            sourceFiles[
                URL(fileURLWithPath: sourceURL.path + "-journal")
            ]
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationURL.path + "-shm"
            )
        )
        XCTAssertEqual(
            try storeFamilySnapshot(at: sourceURL),
            originalSourceFiles
        )
    }

    func testMetadataProbe_whenObjectiveCExceptionIsRaised_thenFailsClosedOnPrivateCopiesAndNeverMutatesSource() throws {
        let currentModel = try model(for: .version14)
        try createStore(
            at: storeURL,
            model: currentModel
        ) { context in
            self.insertCurrentWallet(
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreSnapshot(at: storeURL)
        var probedURLs = [URL]()
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            metadataReader: { url in
                probedURLs.append(url)
                NSException(
                    name: .invalidArgumentException,
                    reason: "private metadata probe failure",
                    userInfo: ["stored-payload": "must-not-escape"]
                ).raise()
                return [:]
            }
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            guard
                let migrationError =
                error as? UserStorageMigrationError,
                case .objectiveCException = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(probedURLs.count, 2)
        XCTAssertTrue(
            probedURLs.allSatisfy {
                $0.standardizedFileURL !=
                    self.storeURL.standardizedFileURL
            }
        )
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testMetadataProbe_whenSourceHasHotRollbackJournal_thenRecoversOnlyPrivateCopyAndLeavesSourceFamilyByteIdentical() throws {
        let currentModel = try model(for: .version14)
        try createStore(
            at: storeURL,
            model: currentModel
        ) { context in
            self.insertCurrentWallet(
                in: context,
                model: currentModel
            )
        }

        let database = try openSQLite(at: storeURL)
        defer {
            try? executeSQLite(
                "ROLLBACK",
                database: database
            )
            sqlite3_close(database)
        }
        try executeSQLite(
            "PRAGMA journal_mode = DELETE; " +
                "BEGIN IMMEDIATE; " +
                "UPDATE ZCDMETAACCOUNT " +
                "SET ZNAME = 'uncommitted-name';",
            database: database
        )

        let journalURL = URL(
            fileURLWithPath: storeURL.path + "-journal"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: journalURL.path
            )
        )
        XCTAssertFalse(
            try Data(contentsOf: journalURL).isEmpty
        )

        let before = try durableStoreSnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertFalse(try migrator.performMigration())
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testSynchronousMigration_whenStoreIsCurrent_thenUsesSinglePrivateMetadataProbe() throws {
        let currentModel = try model(for: .version14)
        try createStore(
            at: storeURL,
            model: currentModel
        ) { context in
            self.insertCurrentWallet(
                in: context,
                model: currentModel
            )
        }
        let before = try durableStoreSnapshot(at: storeURL)
        var probedURLs = [URL]()
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            metadataReader: { url in
                probedURLs.append(url)
                return try NSPersistentStoreCoordinator
                    .metadataForPersistentStore(
                        ofType: NSSQLiteStoreType,
                        at: url,
                        options: nil
                    )
            }
        )

        try (migrator as Migrating).migrate()

        XCTAssertEqual(probedURLs.count, 1)
        XCTAssertNotEqual(
            probedURLs.first?.standardizedFileURL,
            storeURL.standardizedFileURL
        )
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            before
        )
    }

    func testPerformMigration_whenStoreAlreadyCurrent_thenRepeatedCallsAreByteForByteIdempotent() throws {
        let currentModel = try model(for: .version14)
        try createStore(at: storeURL, model: currentModel) { context in
            self.insertCurrentWallet(in: context, model: currentModel)
        }

        let before = try durableStoreSnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertFalse(migrator.requiresMigration())
        try migrator.performMigration()
        try migrator.performMigration()

        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertEqual(try durableStoreSnapshot(at: storeURL), before)
        XCTAssertEqual(
            try walletSnapshots(from: storeURL, model: currentModel).map(\.metaId),
            ["current-wallet"]
        )
    }

    func testPerformMigration_whenStoreIsCorrupt_thenThrowsAndDoesNotModifyFiles() throws {
        try Data("not-a-core-data-store".utf8).write(to: storeURL, options: .atomic)
        let before = try storeFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard let migrationError = error as? UserStorageMigrationError else {
                return XCTFail("Unexpected error: \(error)")
            }

            guard case .metadataUnreadable = migrationError else {
                return XCTFail("Expected metadataUnreadable, got \(migrationError)")
            }
        }
        XCTAssertEqual(try storeFamilySnapshot(at: storeURL), before)
    }

    func testPerformMigration_whenStoreModelIsUnknown_thenThrowsAndDoesNotModifyFiles() throws {
        try createStore(at: storeURL, model: makeUnknownModel()) { _ in }
        let before = try storeFamilySnapshot(at: storeURL)
        let migrator = makeMigrator()

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard let migrationError = error as? UserStorageMigrationError else {
                return XCTFail("Unexpected error: \(error)")
            }

            guard case .unknownStoreVersion = migrationError else {
                return XCTFail("Expected unknownStoreVersion, got \(migrationError)")
            }
        }
        XCTAssertEqual(try storeFamilySnapshot(at: storeURL), before)
    }

    func testPerformMigration_whenProcessDiesAfterRemovingLiveMainStore_thenRelaunchRestoresAndMigratesProtectedWallets() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(
                in: context,
                model: legacyModel
            )
        }
        let sourceWallets = try walletSnapshots(
            from: storeURL,
            model: legacyModel
        )
        let interruptedMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { targetURL, _ in
                try FileManager.default.removeItem(at: targetURL)
                throw CrashConsistentStoreReplacementInterruption
                    .simulatedProcessDeath
            }
        )

        XCTAssertThrowsError(
            try interruptedMigrator.performMigration()
        ) { error in
            guard
                let interruption = error as? CrashConsistentStoreReplacementInterruption,
                case .simulatedProcessDeath = interruption
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: storeURL.path),
            "The fixture must reproduce the missing-main startup state"
        )

        let relaunchedMigrator = makeMigrator()
        XCTAssertTrue(try relaunchedMigrator.performMigration())

        XCTAssertEqual(
            try metadataChecksum(at: storeURL),
            currentChecksum
        )
        XCTAssertEqual(
            try walletSnapshots(
                from: storeURL,
                model: model(for: .version14)
            ),
            sourceWallets
        )
        XCTAssertFalse(relaunchedMigrator.requiresMigration())
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: testDirectory
                    .appendingPathComponent(
                        ".FearlessStoreReplacement",
                        isDirectory: true
                    ).path
            )
        )
    }

    func testPerformMigration_whenStoreReplacementFails_thenProtectedDataIsNeverFinalized() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        let walletsBeforeMigration = try walletSnapshots(
            from: storeURL,
            model: legacyModel
        )
        let recorder = UserStorageCommitRecorder()
        let keystoreMigrator = RecordingKeystoreMigrator(
            recorder: recorder
        )
        let settingsMigrator = RecordingSettingsMigrator(
            recorder: recorder
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, _ in
                recorder.record(.storeReplacement)
                throw UserStorageCommitTestError.storeReplacementFailed
            },
            keystoreMigratorFactory: { _, _, _ in keystoreMigrator },
            settingsMigratorFactory: { _, _, _ in settingsMigrator }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            XCTAssertEqual(
                error as? UserStorageCommitTestError,
                .storeReplacementFailed
            )
        }

        XCTAssertEqual(
            recorder.events,
            [
                .keystorePrepare,
                .settingsPrepare,
                .storeReplacement
            ]
        )
        XCTAssertEqual(try metadataChecksum(at: storeURL), legacyChecksum)
        XCTAssertEqual(
            try walletSnapshots(from: storeURL, model: legacyModel),
            walletsBeforeMigration
        )
    }

    func testPerformMigration_whenStoreReplacementSucceeds_thenProtectedDataFinalizesAfterward() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        let recorder = UserStorageCommitRecorder()
        let keystoreMigrator = RecordingKeystoreMigrator(
            recorder: recorder
        )
        let settingsMigrator = RecordingSettingsMigrator(
            recorder: recorder
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { targetURL, sourceURL in
                recorder.record(.storeReplacement)
                try NSPersistentStoreCoordinator.replaceStore(
                    at: targetURL,
                    withStoreAt: sourceURL
                )
            },
            keystoreMigratorFactory: { _, _, _ in keystoreMigrator },
            settingsMigratorFactory: { _, _, _ in settingsMigrator }
        )

        try migrator.performMigration()

        XCTAssertEqual(
            recorder.events,
            [
                .keystorePrepare,
                .settingsPrepare,
                .storeReplacement,
                .keystoreFinalize,
                .settingsFinalize
            ]
        )
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)
    }

    func testSettingsCleanup_whenReplacementFailsBeforeCommit_thenRelaunchRollsBackJournalWithoutDeletingLegacySelections() throws {
        let legacyModel = try model(for: .version13)
        try createStore(
            at: storeURL,
            model: legacyModel
        ) { context in
            self.insertCurrentWallet(
                in: context,
                model: legacyModel
            )
        }
        let sourceBefore = try durableStoreSnapshot(at: storeURL)
        let settings = InMemorySettingsManager()
        settings.set(
            value: "legacy-account",
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(
            value: "legacy-connection",
            for: SettingsKey.selectedConnection.rawValue
        )
        let cleanupMigrator =
            CleanupJournalSettingsMigrator(
                sourceVersion: .version13,
                destinationVersion: .version14,
                settings: settings
            )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, _ in
                throw UserStorageCommitTestError
                    .storeReplacementFailed
            },
            settingsMigratorFactory: {
                _,
                    _,
                    _ in

                cleanupMigrator
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            XCTAssertEqual(
                error as? UserStorageCommitTestError,
                .storeReplacementFailed
            )
        }
        XCTAssertNotNil(
            settings.data(
                for: SettingsMigrator.pendingCleanupKey
            )
        )
        XCTAssertEqual(
            try durableStoreSnapshot(at: storeURL),
            sourceBefore
        )

        XCTAssertTrue(
            try UserStorageMigrator(
                targetVersion: .version14,
                storeURL: storeURL,
                modelDirectory:
                UserStorageParams.modelDirectory,
                keystore: InMemoryKeychain(),
                settings: settings,
                fileManager: .default,
                modelBundle: appBundle
            ).performMigration()
        )

        XCTAssertEqual(
            settings.string(
                for: SettingsKey.selectedAccount.rawValue
            ),
            "legacy-account"
        )
        XCTAssertEqual(
            settings.string(
                for: SettingsKey.selectedConnection.rawValue
            ),
            "legacy-connection"
        )
        XCTAssertNil(
            settings.anyValue(
                for: SettingsMigrator.pendingCleanupKey
            )
        )
    }

    func testSettingsCleanup_whenProcessStopsAfterDatabaseReplacement_thenCurrentVersionRelaunchFinishesCleanup() throws {
        let legacyModel = try model(for: .version13)
        try createStore(
            at: storeURL,
            model: legacyModel
        ) { context in
            self.insertCurrentWallet(
                in: context,
                model: legacyModel
            )
        }
        let settings = InMemorySettingsManager()
        settings.set(
            value: "legacy-account",
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(
            value: "legacy-connection",
            for: SettingsKey.selectedConnection.rawValue
        )
        let cleanupMigrator =
            CleanupJournalSettingsMigrator(
                sourceVersion: .version13,
                destinationVersion: .version14,
                settings: settings
            )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            modelBundle: appBundle,
            settingsMigratorFactory: {
                _,
                    _,
                    _ in

                cleanupMigrator
            },
            storeReplacementBoundaryHook: { boundary in
                guard boundary == .committedMarkerPersisted else {
                    return
                }

                throw CrashConsistentStoreReplacementInterruption
                    .simulatedProcessDeath
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        )
        XCTAssertEqual(
            try metadataChecksum(at: storeURL),
            currentChecksum
        )
        XCTAssertNotNil(
            settings.data(
                for: SettingsMigrator.pendingCleanupKey
            )
        )
        XCTAssertEqual(
            settings.string(
                for: SettingsKey.selectedAccount.rawValue
            ),
            "legacy-account"
        )

        let relaunchedMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertFalse(
            try relaunchedMigrator.performMigration()
        )
        XCTAssertNil(
            settings.anyValue(
                for: SettingsKey.selectedAccount.rawValue
            )
        )
        XCTAssertNil(
            settings.anyValue(
                for: SettingsKey.selectedConnection.rawValue
            )
        )
        XCTAssertNil(
            settings.anyValue(
                for: SettingsMigrator.pendingCleanupKey
            )
        )
    }

    func testSettingsCleanup_whenFinalizeFails_thenErrorPropagatesAndCurrentVersionRelaunchRetriesIdempotently() throws {
        let legacyModel = try model(for: .version13)
        try createStore(
            at: storeURL,
            model: legacyModel
        ) { context in
            self.insertCurrentWallet(
                in: context,
                model: legacyModel
            )
        }
        let settings = InMemorySettingsManager()
        settings.set(
            value: "legacy-account",
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(
            value: "legacy-connection",
            for: SettingsKey.selectedConnection.rawValue
        )
        let cleanupMigrator =
            CleanupJournalSettingsMigrator(
                sourceVersion: .version13,
                destinationVersion: .version14,
                settings: settings,
                finalizeError: UserStorageCommitTestError
                    .settingsFinalizeFailed
            )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            modelBundle: appBundle,
            settingsMigratorFactory: {
                _,
                    _,
                    _ in

                cleanupMigrator
            }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            XCTAssertEqual(
                error as? UserStorageCommitTestError,
                .settingsFinalizeFailed
            )
        }
        XCTAssertEqual(
            try metadataChecksum(at: storeURL),
            currentChecksum
        )
        XCTAssertNotNil(
            settings.data(
                for: SettingsMigrator.pendingCleanupKey
            )
        )

        let relaunchedMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertFalse(
            try relaunchedMigrator.performMigration()
        )
        XCTAssertFalse(
            try relaunchedMigrator.performMigration()
        )
        XCTAssertNil(
            settings.anyValue(
                for: SettingsKey.selectedAccount.rawValue
            )
        )
        XCTAssertNil(
            settings.anyValue(
                for: SettingsKey.selectedConnection.rawValue
            )
        )
        XCTAssertNil(
            settings.anyValue(
                for: SettingsMigrator.pendingCleanupKey
            )
        )
    }

    func testSettingsCleanup_whenJournalIsValid_thenDeletesOnlyExactLegacySelections() throws {
        let settings = InMemorySettingsManager()
        let unrelatedKey = "io.fearless.oauth.refresh-token"
        settings.set(value: "legacy-account", for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: "legacy-connection", for: SettingsKey.selectedConnection.rawValue)
        settings.set(value: "keep-me", for: unrelatedKey)
        let journal = try JSONSerialization.data(
            withJSONObject: [
                "schemaVersion": 1,
                "sourceVersion": UserStorageVersion.version13.rawValue,
                "destinationVersion": UserStorageVersion.version14.rawValue,
                "keysToRemove": [
                    SettingsKey.selectedAccount.rawValue,
                    SettingsKey.selectedConnection.rawValue
                ]
            ],
            options: [.sortedKeys]
        )
        settings.set(value: journal, for: SettingsMigrator.pendingCleanupKey)

        try SettingsMigrator.recoverPendingCleanup(
            settings: settings,
            currentVersion: .version14
        )

        XCTAssertNil(settings.anyValue(for: SettingsKey.selectedAccount.rawValue))
        XCTAssertNil(settings.anyValue(for: SettingsKey.selectedConnection.rawValue))
        XCTAssertEqual(settings.string(for: unrelatedKey), "keep-me")
        XCTAssertNil(settings.anyValue(for: SettingsMigrator.pendingCleanupKey))
    }

    func testSettingsCleanup_whenJournalTargetsUnrelatedKey_thenFailsClosedAndPreservesEverything() throws {
        let settings = InMemorySettingsManager()
        let unrelatedKey = "io.fearless.oauth.refresh-token"
        settings.set(value: "legacy-account", for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: "legacy-connection", for: SettingsKey.selectedConnection.rawValue)
        settings.set(value: "keep-me", for: unrelatedKey)
        let journal = try JSONSerialization.data(
            withJSONObject: [
                "schemaVersion": 1,
                "sourceVersion": UserStorageVersion.version13.rawValue,
                "destinationVersion": UserStorageVersion.version14.rawValue,
                "keysToRemove": [
                    SettingsKey.selectedAccount.rawValue,
                    unrelatedKey
                ]
            ],
            options: [.sortedKeys]
        )
        settings.set(value: journal, for: SettingsMigrator.pendingCleanupKey)

        XCTAssertThrowsError(
            try SettingsMigrator.recoverPendingCleanup(
                settings: settings,
                currentVersion: .version14
            )
        ) { error in
            guard
                let migrationError = error as? SettingsMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(
            settings.string(for: SettingsKey.selectedAccount.rawValue),
            "legacy-account"
        )
        XCTAssertEqual(
            settings.string(for: SettingsKey.selectedConnection.rawValue),
            "legacy-connection"
        )
        XCTAssertEqual(settings.string(for: unrelatedKey), "keep-me")
        XCTAssertEqual(
            settings.data(for: SettingsMigrator.pendingCleanupKey),
            journal
        )
    }

    func testSettingsCleanup_whenJournalHasDuplicateField_thenFailsClosed() {
        let settings = InMemorySettingsManager()
        settings.set(value: "legacy-account", for: SettingsKey.selectedAccount.rawValue)
        let journal = Data(
            """
            {"schemaVersion":1,"schemaVersion":1,"sourceVersion":"version13","destinationVersion":"version14","keysToRemove":["selectedAccount","selectedConnection"]}
            """.utf8
        )
        settings.set(value: journal, for: SettingsMigrator.pendingCleanupKey)

        XCTAssertThrowsError(
            try SettingsMigrator.recoverPendingCleanup(
                settings: settings,
                currentVersion: .version14
            )
        )
        XCTAssertEqual(
            settings.string(for: SettingsKey.selectedAccount.rawValue),
            "legacy-account"
        )
        XCTAssertEqual(
            settings.data(for: SettingsMigrator.pendingCleanupKey),
            journal
        )
    }

    func testSettingsCleanup_whenJournalHasUnknownField_thenFailsClosed() throws {
        let settings = InMemorySettingsManager()
        settings.set(value: "legacy-account", for: SettingsKey.selectedAccount.rawValue)
        let journal = try JSONSerialization.data(
            withJSONObject: [
                "schemaVersion": 1,
                "sourceVersion": UserStorageVersion.version13.rawValue,
                "destinationVersion": UserStorageVersion.version14.rawValue,
                "keysToRemove": [
                    SettingsKey.selectedAccount.rawValue,
                    SettingsKey.selectedConnection.rawValue
                ],
                "unexpected": true
            ],
            options: [.sortedKeys]
        )
        settings.set(value: journal, for: SettingsMigrator.pendingCleanupKey)

        XCTAssertThrowsError(
            try SettingsMigrator.recoverPendingCleanup(
                settings: settings,
                currentVersion: .version14
            )
        )
        XCTAssertEqual(
            settings.string(for: SettingsKey.selectedAccount.rawValue),
            "legacy-account"
        )
        XCTAssertEqual(
            settings.data(for: SettingsMigrator.pendingCleanupKey),
            journal
        )
    }

    func testSettingsCleanup_whenJournalIsOversized_thenFailsBeforeDeletingAnything() {
        let settings = InMemorySettingsManager()
        settings.set(value: "legacy-account", for: SettingsKey.selectedAccount.rawValue)
        let journal = Data(repeating: 0x20, count: 4_097)
        settings.set(value: journal, for: SettingsMigrator.pendingCleanupKey)

        XCTAssertThrowsError(
            try SettingsMigrator.recoverPendingCleanup(
                settings: settings,
                currentVersion: .version14
            )
        )
        XCTAssertEqual(
            settings.string(for: SettingsKey.selectedAccount.rawValue),
            "legacy-account"
        )
        XCTAssertEqual(
            settings.data(for: SettingsMigrator.pendingCleanupKey),
            journal
        )
    }

    func testPerformMigration_whenKeychainReadFails_thenPropagatesAndLeavesLegacyStoreUntouched() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        let walletsBeforeMigration = try walletSnapshots(
            from: storeURL,
            model: legacyModel
        )
        let keystore = FaultInjectingKeystore()
        keystore.failures.insert(
            .fetch(KeystoreMigrator.pendingCleanupIdentifier)
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            XCTAssertEqual(
                error as? FaultInjectingKeystore.Error,
                .injected(.fetch(KeystoreMigrator.pendingCleanupIdentifier))
            )
        }
        XCTAssertEqual(try metadataChecksum(at: storeURL), legacyChecksum)
        XCTAssertEqual(
            try walletSnapshots(from: storeURL, model: legacyModel),
            walletsBeforeMigration
        )
    }

    func testPerformMigration_whenReplacementKeySaveFails_thenNeverReplacesStoreOrDeletesLegacyKey() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        let legacyIdentifier = try legacyDeletionIdentifier(0x01)
        let replacementIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0x01, 0x02])
        let replacementKey = Data([0x03, 0x04])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        keystore.failures.insert(.add(replacementIdentifier))

        let keystoreMigrator = KeystoreMigrator(
            sourceVersion: .version13,
            destinationVersion: .version14,
            keystore: keystore
        )
        keystoreMigrator.deleteKey(for: legacyIdentifier)
        keystoreMigrator.save(
            key: replacementKey,
            for: replacementIdentifier
        )
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, _ in
                replacementAttempted = true
            },
            keystoreMigratorFactory: { _, _, _ in keystoreMigrator }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            XCTAssertEqual(
                error as? FaultInjectingKeystore.Error,
                .injected(.add(replacementIdentifier))
            )
        }
        XCTAssertFalse(replacementAttempted)
        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertNil(keystore.value(for: replacementIdentifier))
        XCTAssertNotNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
        XCTAssertEqual(try metadataChecksum(at: storeURL), legacyChecksum)

        keystore.failures.remove(.add(replacementIdentifier))
        try KeystoreMigrator.recoverPendingCleanup(
            keystore: keystore,
            currentVersion: .version13
        )
        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertNil(keystore.value(for: replacementIdentifier))
        XCTAssertNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
    }

    func testPerformMigration_whenStoreReplacementFails_thenKeepsOldAndStagedKeysUntilSafeRollback() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        let legacyIdentifier = try legacyDeletionIdentifier(0x11)
        let replacementIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0x11, 0x12])
        let replacementKey = Data([0x13, 0x14])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        let keystoreMigrator = KeystoreMigrator(
            sourceVersion: .version13,
            destinationVersion: .version14,
            keystore: keystore
        )
        keystoreMigrator.deleteKey(for: legacyIdentifier)
        keystoreMigrator.save(
            key: replacementKey,
            for: replacementIdentifier
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { _, _ in
                XCTAssertEqual(
                    keystore.value(for: legacyIdentifier),
                    legacyKey
                )
                XCTAssertEqual(
                    keystore.value(for: replacementIdentifier),
                    replacementKey
                )
                throw UserStorageCommitTestError.storeReplacementFailed
            },
            keystoreMigratorFactory: { _, _, _ in keystoreMigrator }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            XCTAssertEqual(
                error as? UserStorageCommitTestError,
                .storeReplacementFailed
            )
        }
        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertEqual(
            keystore.value(for: replacementIdentifier),
            replacementKey
        )
        XCTAssertNotNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
        XCTAssertEqual(try metadataChecksum(at: storeURL), legacyChecksum)

        try KeystoreMigrator.recoverPendingCleanup(
            keystore: keystore,
            currentVersion: .version13
        )
        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertNil(keystore.value(for: replacementIdentifier))
        XCTAssertNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
    }

    func testPerformMigration_whenPostReplacementCleanupFails_thenFailsAndRelaunchFinishesCleanupWithoutLosingNewKey() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        let legacyIdentifier = try legacyDeletionIdentifier(0x21)
        let replacementIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0x21, 0x22])
        let replacementKey = Data([0x23, 0x24])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        keystore.failures.insert(.delete(legacyIdentifier))
        let keystoreMigrator = KeystoreMigrator(
            sourceVersion: .version13,
            destinationVersion: .version14,
            keystore: keystore
        )
        keystoreMigrator.deleteKey(for: legacyIdentifier)
        keystoreMigrator.save(
            key: replacementKey,
            for: replacementIdentifier
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            keystoreMigratorFactory: { _, _, _ in keystoreMigrator }
        )

        XCTAssertThrowsError(
            try migrator.performMigration()
        ) { error in
            XCTAssertEqual(
                error as? FaultInjectingKeystore.Error,
                .injected(.delete(legacyIdentifier))
            )
        }
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)
        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertEqual(
            keystore.value(for: replacementIdentifier),
            replacementKey
        )
        XCTAssertNotNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )

        keystore.failures.remove(.delete(legacyIdentifier))
        let relaunchedMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertNoThrow(try relaunchedMigrator.migrate())
        XCTAssertNil(keystore.value(for: legacyIdentifier))
        XCTAssertEqual(
            keystore.value(for: replacementIdentifier),
            replacementKey
        )
        XCTAssertNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)
    }

    func testMigrate_whenDestinationSecretVerificationFails_thenReturnsFailureAndRetryConvergesOnlyAfterRepair() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(
                in: context,
                model: legacyModel
            )
        }
        let legacyIdentifier = try legacyDeletionIdentifier(0x25)
        let destinationIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0x25, 0x26])
        let destinationKey = Data([0x27, 0x28])
        let corruptedDestinationKey = Data([0x29, 0x2A])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        let journalMigrator = KeystoreMigrator(
            sourceVersion: .version13,
            destinationVersion: .version14,
            keystore: keystore
        )
        journalMigrator.deleteKey(for: legacyIdentifier)
        journalMigrator.save(
            key: destinationKey,
            for: destinationIdentifier
        )
        let failingFinalizeMigrator =
            MappingFinalizeFailureKeystoreMigrator(
                migrator: journalMigrator,
                mappedError: UserStorageCommitTestError
                    .keystoreFinalizeFailed
            )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { targetURL, sourceURL in
                try NSPersistentStoreCoordinator.replaceStore(
                    at: targetURL,
                    withStoreAt: sourceURL
                )
                try keystore.updateKey(
                    corruptedDestinationKey,
                    with: destinationIdentifier
                )
            },
            keystoreMigratorFactory: {
                _,
                    _,
                    _ in

                failingFinalizeMigrator
            }
        )

        XCTAssertThrowsError(
            try migrator.migrate()
        ) { error in
            XCTAssertEqual(
                error as? UserStorageCommitTestError,
                .keystoreFinalizeFailed
            )
        }
        guard
            let finalizeError =
            failingFinalizeMigrator.underlyingFinalizeError
                as? KeystoreMigratingError,
            case let .cleanupDestinationKeyVerificationFailed(
                identifier
            ) = finalizeError
        else {
            return XCTFail(
                "Expected destination-key verification failure"
            )
        }
        XCTAssertEqual(identifier, destinationIdentifier)
        XCTAssertEqual(
            try metadataChecksum(at: storeURL),
            currentChecksum
        )
        let journal = try XCTUnwrap(
            keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
        XCTAssertEqual(
            keystore.value(for: legacyIdentifier),
            legacyKey
        )
        XCTAssertEqual(
            keystore.value(for: destinationIdentifier),
            corruptedDestinationKey
        )

        let relaunchedMigrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertThrowsError(
            try relaunchedMigrator.migrate()
        ) { error in
            guard
                let migrationError =
                error as? KeystoreMigratingError,
                case let .cleanupDestinationKeyVerificationFailed(
                    identifier
                ) = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(identifier, destinationIdentifier)
        }
        XCTAssertEqual(
            keystore.value(for: legacyIdentifier),
            legacyKey
        )
        XCTAssertEqual(
            keystore.value(for: destinationIdentifier),
            corruptedDestinationKey
        )
        XCTAssertEqual(
            keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ),
            journal
        )

        try keystore.updateKey(
            destinationKey,
            with: destinationIdentifier
        )
        XCTAssertNoThrow(try relaunchedMigrator.migrate())
        XCTAssertNil(keystore.value(for: legacyIdentifier))
        XCTAssertEqual(
            keystore.value(for: destinationIdentifier),
            destinationKey
        )
        XCTAssertNil(
            keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
        XCTAssertNoThrow(try relaunchedMigrator.migrate())
        XCTAssertEqual(
            try metadataChecksum(at: storeURL),
            currentChecksum
        )
    }

    func testPerformMigration_whenCurrentStoreCleanupJournalIsCorrupt_thenLaunchFailsClosed() throws {
        let currentModel = try model(for: .version14)
        try createStore(at: storeURL, model: currentModel) { context in
            self.insertCurrentWallet(in: context, model: currentModel)
        }
        let corruptJournal = Data("not-json".utf8)
        let keystore = FaultInjectingKeystore(
            values: [
                KeystoreMigrator.pendingCleanupIdentifier: corruptJournal
            ]
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertThrowsError(try migrator.migrate())
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)
        XCTAssertEqual(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier),
            corruptJournal
        )
    }

    func testPerformMigration_whenCurrentStoreCleanupJournalCannotBeRead_thenBlocksAndRetriesWithoutDeletingKeys() throws {
        let currentModel = try model(for: .version14)
        try createStore(at: storeURL, model: currentModel) { context in
            self.insertCurrentWallet(in: context, model: currentModel)
        }
        let fixture = try prepareCleanupJournalFixture()
        let journal = try XCTUnwrap(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
        fixture.keystore.failures.insert(
            .fetch(KeystoreMigrator.pendingCleanupIdentifier)
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: fixture.keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertThrowsError(try migrator.migrate()) { error in
            XCTAssertEqual(
                error as? FaultInjectingKeystore.Error,
                .injected(
                    .fetch(KeystoreMigrator.pendingCleanupIdentifier)
                )
            )
        }
        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: journal
        )

        fixture.keystore.failures.remove(
            .fetch(KeystoreMigrator.pendingCleanupIdentifier)
        )
        XCTAssertNoThrow(try migrator.migrate())

        XCTAssertNil(
            fixture.keystore.value(for: fixture.legacyIdentifier)
        )
        XCTAssertEqual(
            fixture.keystore.value(for: fixture.destinationIdentifier),
            fixture.destinationKey
        )
        XCTAssertNil(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)
        XCTAssertEqual(
            try walletSnapshots(from: storeURL, model: currentModel).map(\.metaId),
            ["current-wallet"]
        )
    }

    func testPerformMigration_whenCurrentStoreDestinationKeyIsMissing_thenBlocksUntilKeyIsRestored() throws {
        let currentModel = try model(for: .version14)
        try createStore(at: storeURL, model: currentModel) { context in
            self.insertCurrentWallet(in: context, model: currentModel)
        }
        let fixture = try prepareCleanupJournalFixture()
        try fixture.keystore.deleteKey(
            for: fixture.destinationIdentifier
        )
        let journal = try XCTUnwrap(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: fixture.keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertThrowsError(try migrator.migrate()) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case let .cleanupDestinationKeyMissing(identifier) = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(identifier, fixture.destinationIdentifier)
        }
        XCTAssertEqual(
            fixture.keystore.value(for: fixture.legacyIdentifier),
            fixture.legacyKey
        )
        XCTAssertEqual(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ),
            journal
        )

        try fixture.keystore.addKey(
            fixture.destinationKey,
            with: fixture.destinationIdentifier
        )
        XCTAssertNoThrow(try migrator.migrate())

        XCTAssertNil(
            fixture.keystore.value(for: fixture.legacyIdentifier)
        )
        XCTAssertEqual(
            fixture.keystore.value(for: fixture.destinationIdentifier),
            fixture.destinationKey
        )
        XCTAssertNil(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    func testPerformMigration_whenCurrentStoreDestinationProofIsTampered_thenBlocksUntilJournalIsRestored() throws {
        let currentModel = try model(for: .version14)
        try createStore(at: storeURL, model: currentModel) { context in
            self.insertCurrentWallet(in: context, model: currentModel)
        }
        let fixture = try prepareCleanupJournalFixture()
        let originalJournal = try XCTUnwrap(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
        let tamperedJournal = try rewriteCleanupJournal(
            in: fixture.keystore
        ) { journal in
            var proofs = try XCTUnwrap(
                journal["destinationKeyProofs"] as? [[String: Any]]
            )
            proofs[0]["sha256"] = Data(
                repeating: 0xFF,
                count: 32
            ).base64EncodedString()
            journal["destinationKeyProofs"] = proofs
        }
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: fixture.keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertThrowsError(try migrator.migrate()) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .cleanupDestinationKeyVerificationFailed = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: tamperedJournal
        )

        try fixture.keystore.updateKey(
            originalJournal,
            with: KeystoreMigrator.pendingCleanupIdentifier
        )
        XCTAssertNoThrow(try migrator.migrate())

        XCTAssertNil(
            fixture.keystore.value(for: fixture.legacyIdentifier)
        )
        XCTAssertEqual(
            fixture.keystore.value(for: fixture.destinationIdentifier),
            fixture.destinationKey
        )
        XCTAssertNil(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )
    }

    func testPerformMigration_whenSourceStoreHasLegacyCleanupJournal_thenRerunsWithExistingStagedKey() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        let legacyIdentifier = try legacyDeletionIdentifier(0x91)
        let destinationIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0x91, 0x92])
        let destinationKey = Data([0x93, 0x94])
        let legacyJournal = try legacyCleanupJournalData(
            sourceVersion: .version13,
            destinationVersion: .version14,
            identifiersToRemove: [legacyIdentifier],
            stagedIdentifiers: [destinationIdentifier]
        )
        let keystore = FaultInjectingKeystore(
            values: [
                legacyIdentifier: legacyKey,
                destinationIdentifier: destinationKey,
                KeystoreMigrator.pendingCleanupIdentifier: legacyJournal
            ]
        )
        let keystoreMigrator = KeystoreMigrator(
            sourceVersion: .version13,
            destinationVersion: .version14,
            keystore: keystore
        )
        keystoreMigrator.deleteKey(for: legacyIdentifier)
        keystoreMigrator.save(
            key: destinationKey,
            for: destinationIdentifier
        )
        var replacementAttempted = false
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle,
            storeReplacer: { targetURL, sourceURL in
                replacementAttempted = true
                XCTAssertEqual(
                    keystore.value(for: legacyIdentifier),
                    legacyKey
                )
                XCTAssertEqual(
                    keystore.value(for: destinationIdentifier),
                    destinationKey
                )
                try NSPersistentStoreCoordinator.replaceStore(
                    at: targetURL,
                    withStoreAt: sourceURL
                )
            },
            keystoreMigratorFactory: { _, _, _ in
                keystoreMigrator
            }
        )

        try migrator.performMigration()

        XCTAssertTrue(replacementAttempted)
        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)
        XCTAssertNil(keystore.value(for: legacyIdentifier))
        XCTAssertEqual(
            keystore.value(for: destinationIdentifier),
            destinationKey
        )
        XCTAssertNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
    }

    func testMigrate_whenDestinationStoreHasLegacyCleanupJournal_thenClearsOnlyJournal() throws {
        let currentModel = try model(for: .version14)
        try createStore(at: storeURL, model: currentModel) { context in
            self.insertCurrentWallet(in: context, model: currentModel)
        }
        let legacyIdentifier = try legacyDeletionIdentifier(0xB1)
        let destinationIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0xB1, 0xB2])
        let destinationKey = Data([0xB3, 0xB4])
        let legacyJournal = try legacyCleanupJournalData(
            sourceVersion: .version13,
            destinationVersion: .version14,
            identifiersToRemove: [legacyIdentifier],
            stagedIdentifiers: [destinationIdentifier]
        )
        let keystore = FaultInjectingKeystore(
            values: [
                legacyIdentifier: legacyKey,
                destinationIdentifier: destinationKey,
                KeystoreMigrator.pendingCleanupIdentifier: legacyJournal
            ]
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertNoThrow(try migrator.migrate())

        XCTAssertEqual(try metadataChecksum(at: storeURL), currentChecksum)
        XCTAssertEqual(
            keystore.value(for: legacyIdentifier),
            legacyKey
        )
        XCTAssertEqual(
            keystore.value(for: destinationIdentifier),
            destinationKey
        )
        XCTAssertNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
    }

    func testCleanupRecovery_whenLegacyJournalContainsReservedIdentifier_thenFailsClosed() throws {
        let legacyIdentifier = try legacyDeletionIdentifier(0xC1)
        let stagedIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0xC1, 0xC2])
        let stagedKey = Data([0xC3, 0xC4])
        let legacyJournal = try legacyCleanupJournalData(
            sourceVersion: .version1,
            destinationVersion: .version2,
            identifiersToRemove: [
                legacyIdentifier,
                KeystoreMigrator.pendingCleanupIdentifier
            ],
            stagedIdentifiers: [stagedIdentifier]
        )
        let keystore = FaultInjectingKeystore(
            values: [
                legacyIdentifier: legacyKey,
                stagedIdentifier: stagedKey,
                KeystoreMigrator.pendingCleanupIdentifier: legacyJournal
            ]
        )

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: keystore,
                currentVersion: .version1
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertEqual(keystore.value(for: stagedIdentifier), stagedKey)
        XCTAssertEqual(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier),
            legacyJournal
        )
    }

    func testCleanupRecovery_whenVerifiedJournalDoesNotBracketDatabaseVersion_thenFailsClosed() throws {
        let legacyIdentifier = try legacyDeletionIdentifier(0xD1)
        let destinationIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0xD1, 0xD2])
        let destinationKey = Data([0xD3, 0xD4])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        let migrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .current,
            keystore: keystore
        )

        while migrator.currentVersion != .current {
            try migrator.switchVersion()
        }

        migrator.deleteKey(for: legacyIdentifier)
        migrator.save(
            key: destinationKey,
            for: destinationIdentifier
        )
        try migrator.prepare()
        let journal = try XCTUnwrap(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertEqual(
            keystore.value(for: destinationIdentifier),
            destinationKey
        )
        XCTAssertEqual(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier),
            journal
        )
    }

    func testCleanupRecovery_whenLegacyJournalDoesNotBracketDatabaseVersion_thenFailsClosed() throws {
        let legacyIdentifier = try legacyDeletionIdentifier(0xE1)
        let stagedIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0xE1, 0xE2])
        let stagedKey = Data([0xE3, 0xE4])
        let legacyJournal = try legacyCleanupJournalData(
            sourceVersion: .version1,
            destinationVersion: .current,
            identifiersToRemove: [legacyIdentifier],
            stagedIdentifiers: [stagedIdentifier]
        )
        let keystore = FaultInjectingKeystore(
            values: [
                legacyIdentifier: legacyKey,
                stagedIdentifier: stagedKey,
                KeystoreMigrator.pendingCleanupIdentifier: legacyJournal
            ]
        )

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
        XCTAssertEqual(keystore.value(for: stagedIdentifier), stagedKey)
        XCTAssertEqual(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier),
            legacyJournal
        )
    }

    func testMigrate_whenStoreDoesNotExist_thenReturnsWithoutReadingKeychain() {
        let keystore = FaultInjectingKeystore()
        keystore.failures.insert(
            .fetch(KeystoreMigrator.pendingCleanupIdentifier)
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertNoThrow(try migrator.migrate())
    }

    func testKeystoreMigrator_whenLegacyKeyReadFails_thenErrorIsNotTreatedAsMissingKey() throws {
        let legacyIdentifier = "legacy-key"
        let legacyKey = Data([0x31, 0x32])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        keystore.failures.insert(.fetch(legacyIdentifier))
        let migrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: keystore
        )
        try migrator.switchVersion()

        XCTAssertThrowsError(try migrator.fetchKey(for: legacyIdentifier)) { error in
            XCTAssertEqual(
                error as? FaultInjectingKeystore.Error,
                .injected(.fetch(legacyIdentifier))
            )
        }
        XCTAssertEqual(keystore.value(for: legacyIdentifier), legacyKey)
    }

    func testKeystoreMigrator_whenReplacementIdentifierContainsDifferentKey_thenRefusesToOverwriteIt() throws {
        let replacementIdentifier = "replacement-key"
        let existingKey = Data([0x41, 0x42])
        let attemptedKey = Data([0x43, 0x44])
        let keystore = FaultInjectingKeystore(
            values: [replacementIdentifier: existingKey]
        )
        let migrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: keystore
        )
        try migrator.switchVersion()
        migrator.save(key: attemptedKey, for: replacementIdentifier)

        XCTAssertThrowsError(try migrator.prepare()) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case let .stagedKeyConflict(identifier) = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(identifier, replacementIdentifier)
        }
        XCTAssertEqual(
            keystore.value(for: replacementIdentifier),
            existingKey
        )
        XCTAssertNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
    }

    func testKeystoreMigrator_whenJournalDeletionFails_thenRecoveryCanRepeatWithoutDeletingNewKey() throws {
        let legacyIdentifier = try legacyDeletionIdentifier(0x51)
        let replacementIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0x51, 0x52])
        let replacementKey = Data([0x53, 0x54])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        let migrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: keystore
        )
        try migrator.switchVersion()
        migrator.deleteKey(for: legacyIdentifier)
        migrator.save(key: replacementKey, for: replacementIdentifier)
        try migrator.prepare()
        keystore.failures.insert(
            .delete(KeystoreMigrator.pendingCleanupIdentifier)
        )

        XCTAssertThrowsError(try migrator.finalize()) { error in
            XCTAssertEqual(
                error as? FaultInjectingKeystore.Error,
                .injected(
                    .delete(KeystoreMigrator.pendingCleanupIdentifier)
                )
            )
        }
        XCTAssertNil(keystore.value(for: legacyIdentifier))
        XCTAssertEqual(
            keystore.value(for: replacementIdentifier),
            replacementKey
        )
        XCTAssertNotNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )

        keystore.failures.remove(
            .delete(KeystoreMigrator.pendingCleanupIdentifier)
        )
        try KeystoreMigrator.recoverPendingCleanup(
            keystore: keystore,
            currentVersion: .version2
        )
        try KeystoreMigrator.recoverPendingCleanup(
            keystore: keystore,
            currentVersion: .version2
        )
        XCTAssertNil(keystore.value(for: legacyIdentifier))
        XCTAssertEqual(
            keystore.value(for: replacementIdentifier),
            replacementKey
        )
        XCTAssertNil(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
    }

    func testCleanupRecovery_whenDestinationKeyIsMissing_thenRetainsLegacyKeyAndJournal() throws {
        let fixture = try prepareCleanupJournalFixture()
        try fixture.keystore.deleteKey(for: fixture.destinationIdentifier)
        let journal = try XCTUnwrap(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case let .cleanupDestinationKeyMissing(identifier) = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(identifier, fixture.destinationIdentifier)
        }

        XCTAssertEqual(
            fixture.keystore.value(for: fixture.legacyIdentifier),
            fixture.legacyKey
        )
        XCTAssertNil(
            fixture.keystore.value(for: fixture.destinationIdentifier)
        )
        XCTAssertEqual(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ),
            journal
        )
    }

    func testCleanupRecovery_whenDestinationKeyHasDrifted_thenRetainsLegacyKeyAndJournal() throws {
        let fixture = try prepareCleanupJournalFixture()
        let driftedKey = Data([0xA1, 0xA2, 0xA3])
        try fixture.keystore.updateKey(
            driftedKey,
            with: fixture.destinationIdentifier
        )
        let journal = try XCTUnwrap(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            )
        )

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case let .cleanupDestinationKeyVerificationFailed(identifier) = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(identifier, fixture.destinationIdentifier)
        }

        XCTAssertEqual(
            fixture.keystore.value(for: fixture.legacyIdentifier),
            fixture.legacyKey
        )
        XCTAssertEqual(
            fixture.keystore.value(for: fixture.destinationIdentifier),
            driftedKey
        )
        XCTAssertEqual(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ),
            journal
        )
    }

    func testCleanupRecovery_whenDestinationDigestIsTampered_thenRetainsAllKeysAndJournal() throws {
        let fixture = try prepareCleanupJournalFixture()
        let tamperedJournal = try rewriteCleanupJournal(
            in: fixture.keystore
        ) { journal in
            var proofs = try XCTUnwrap(
                journal["destinationKeyProofs"] as? [[String: Any]]
            )
            XCTAssertEqual(proofs.count, 1)
            proofs[0]["sha256"] = Data(
                repeating: 0xFF,
                count: 32
            ).base64EncodedString()
            journal["destinationKeyProofs"] = proofs
        }

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case let .cleanupDestinationKeyVerificationFailed(identifier) = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(identifier, fixture.destinationIdentifier)
        }

        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: tamperedJournal
        )
    }

    func testCleanupRecovery_whenDeletionListContainsReservedJournalIdentifier_thenFailsClosed() throws {
        let fixture = try prepareCleanupJournalFixture()
        let tamperedJournal = try rewriteCleanupJournal(
            in: fixture.keystore
        ) { journal in
            journal["identifiersToRemove"] = [
                fixture.legacyIdentifier,
                KeystoreMigrator.pendingCleanupIdentifier
            ]
        }

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: tamperedJournal
        )
    }

    func testCleanupRecovery_whenDeletionListContainsDestinationIdentifier_thenFailsClosed() throws {
        let fixture = try prepareCleanupJournalFixture()
        let tamperedJournal = try rewriteCleanupJournal(
            in: fixture.keystore
        ) { journal in
            journal["identifiersToRemove"] = [
                fixture.legacyIdentifier,
                fixture.destinationIdentifier
            ]
        }

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: tamperedJournal
        )
    }

    func testCleanupRecovery_whenDeletionListContainsPincode_thenFailsClosedWithoutDeletingIt() throws {
        let fixture = try prepareCleanupJournalFixture()
        let pincode = Data("246810".utf8)
        try fixture.keystore.addKey(
            pincode,
            with: fearless.KeystoreTag.pincode.rawValue
        )
        let tamperedJournal = try rewriteCleanupJournal(
            in: fixture.keystore
        ) { journal in
            journal["identifiersToRemove"] = [
                fixture.legacyIdentifier,
                fearless.KeystoreTag.pincode.rawValue
            ]
        }

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: tamperedJournal
        )
        XCTAssertEqual(
            fixture.keystore.value(for: fearless.KeystoreTag.pincode.rawValue),
            pincode
        )
    }

    func testCleanupRecovery_whenDeletionListContainsUnrelatedAppKey_thenFailsClosedWithoutDeletingIt() throws {
        let fixture = try prepareCleanupJournalFixture()
        let unrelatedIdentifier = "io.fearless.oauth.refresh-token"
        let unrelatedKey = Data([0xF1, 0xF2, 0xF3])
        try fixture.keystore.addKey(
            unrelatedKey,
            with: unrelatedIdentifier
        )
        let tamperedJournal = try rewriteCleanupJournal(
            in: fixture.keystore
        ) { journal in
            journal["identifiersToRemove"] = [
                fixture.legacyIdentifier,
                unrelatedIdentifier
            ]
        }

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version2
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: tamperedJournal
        )
        XCTAssertEqual(
            fixture.keystore.value(for: unrelatedIdentifier),
            unrelatedKey
        )
    }

    func testCleanupRecovery_whenRollbackStagesPincodeWithMatchingProof_thenFailsClosedWithoutDeletingIt() throws {
        let fixture = try prepareCleanupJournalFixture()
        let pincode = fixture.destinationKey
        try fixture.keystore.addKey(
            pincode,
            with: fearless.KeystoreTag.pincode.rawValue
        )
        let tamperedJournal = try rewriteCleanupJournal(
            in: fixture.keystore
        ) { journal in
            var proofs = try XCTUnwrap(
                journal["destinationKeyProofs"] as? [[String: Any]]
            )
            var forgedPincodeProof = try XCTUnwrap(proofs.first)
            forgedPincodeProof["identifier"] = fearless.KeystoreTag.pincode.rawValue
            proofs.append(forgedPincodeProof)
            journal["destinationKeyProofs"] = proofs
            journal["stagedIdentifiers"] = [
                fearless.KeystoreTag.pincode.rawValue
            ]
        }

        XCTAssertThrowsError(
            try KeystoreMigrator.recoverPendingCleanup(
                keystore: fixture.keystore,
                currentVersion: .version1
            )
        ) { error in
            guard
                let migrationError = error as? KeystoreMigratingError,
                case .invalidCleanupJournal = migrationError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        assertCleanupFixtureIsFullyRetained(
            fixture,
            expectedJournal: tamperedJournal
        )
        XCTAssertEqual(
            fixture.keystore.value(for: fearless.KeystoreTag.pincode.rawValue),
            pincode
        )
    }

    func testMetaAccountMapper_whenMigratedRecordHasOnlyTonFields_thenThrowsRecoverableError() throws {
        let legacyModel = try model(for: .version13)
        try createStore(at: storeURL, model: legacyModel) { context in
            try self.insertLegacyWallets(in: context, model: legacyModel)
        }
        try makeMigrator().performMigration()

        let currentModel = try model(for: .version14)
        try useStore(at: storeURL, model: currentModel) { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(format: "metaId == %@", "ton-only-wallet")
            let object = try XCTUnwrap(context.fetch(request).first)
            let entity = try XCTUnwrap(
                object as? fearless.CDMetaAccount,
                "The active compatibility model must materialize the app's CDMetaAccount class"
            )

            XCTAssertThrowsError(try MetaAccountMapper().transform(entity: entity)) { error in
                guard let mapperError = error as? MetaAccountMapperError else {
                    return XCTFail("Unexpected error: \(error)")
                }

                guard case .unsupportedWalletRecord = mapperError else {
                    return XCTFail("Expected unsupportedWalletRecord, got \(mapperError)")
                }
            }
        }
    }

    func testMetaAccountMapper_whenEvmAccount_thenWritesCanonicalIdentifierAndReadsCanonicalAndLegacyAliases() throws {
        let currentModel = try model(for: .version14)

        try createStore(at: storeURL, model: currentModel) { context in
            let chainAccount = ChainAccountModel(
                chainId: "ethereum-chain",
                accountId: Data(repeating: 0x61, count: 20),
                publicKey: Data(repeating: 0x62, count: 33),
                cryptoType: 2,
                ethereumBased: true
            )
            let walletModel = AccountGenerator.generateMetaAccount(with: [chainAccount])
            let walletEntity = fearless.CDMetaAccount(context: context)
            walletEntity.isSelected = true
            walletEntity.order = 1
            walletEntity.setValue(false, forKey: "zeroBalanceAssetsHidden")
            let mapper = MetaAccountMapper()

            try mapper.populate(
                entity: walletEntity,
                from: walletModel,
                using: context
            )

            let chainEntity = try XCTUnwrap(
                walletEntity.chainAccounts?.allObjects.first as? fearless.CDChainAccount
            )
            XCTAssertEqual(
                chainEntity.value(forKey: "ecosystem") as? String,
                UniversalWalletEcosystem.evm.rawValue
            )

            for ecosystem in [
                UniversalWalletEcosystem.evm.rawValue,
                "ethereum",
                "ethereumBased"
            ] {
                chainEntity.ethereumBased = false
                chainEntity.setValue(ecosystem, forKey: "ecosystem")

                let transformed = try mapper.transform(entity: walletEntity)
                let transformedAccount = try XCTUnwrap(
                    transformed.chainAccounts.first { $0.chainId == chainAccount.chainId }
                )

                XCTAssertTrue(
                    transformedAccount.ethereumBased,
                    "\(ecosystem) must continue to resolve as an EVM account"
                )
            }
        }
    }

    private func makeMigrator(
        storeURL: URL? = nil
    ) -> UserStorageMigrator {
        UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL ?? self.storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
    }

    private func preferenceFixtureValues() -> [String: [String]] {
        [
            "assetFilterOptions": ["filter-option"],
            "assetKeysOrder": ["asset-order"],
            "favouriteChainIds": ["favourite-chain"],
            "unusedChainIds": ["unused-chain"]
        ]
    }

    private func createPreferenceFixture(
        at url: URL,
        sourceVersion: UserStorageVersion,
        values: [String: [String]]
    ) throws {
        let sourceModel = try model(for: sourceVersion)
        try createStore(at: url, model: sourceModel) { context in
            self.insertCurrentWallet(
                in: context,
                model: sourceModel
            )
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDMetaAccount"
            )
            let wallet = try XCTUnwrap(context.fetch(request).first)
            for (key, value) in values {
                wallet.setValue(value as NSArray, forKey: key)
            }
        }
    }

    private func migratedPreferenceValues(
        at url: URL
    ) throws -> [String: [String]] {
        var values = [String: [String]]()
        try useStore(
            at: url,
            model: model(for: .version14)
        ) { context in
            let request = NSFetchRequest<NSManagedObject>(
                entityName: "CDMetaAccount"
            )
            let wallet = try XCTUnwrap(context.fetch(request).first)
            XCTAssertEqual(
                wallet.value(forKey: "metaId") as? String,
                "current-wallet"
            )
            XCTAssertEqual(
                wallet.value(forKey: "substratePublicKey") as? Data,
                Data(repeating: 0x52, count: 32)
            )

            for key in self.preferenceFixtureValues().keys {
                values[key] =
                    wallet.value(forKey: key) as? [String]
            }
        }

        return values
    }

    private typealias CleanupJournalFixture = (
        keystore: FaultInjectingKeystore,
        legacyIdentifier: String,
        destinationIdentifier: String,
        legacyKey: Data,
        destinationKey: Data
    )

    private func prepareCleanupJournalFixture() throws -> CleanupJournalFixture {
        let legacyIdentifier = try legacyDeletionIdentifier(0x71)
        let destinationIdentifier = destinationMigrationIdentifier()
        let legacyKey = Data([0x71, 0x72, 0x73])
        let destinationKey = Data([0x81, 0x82, 0x83])
        let keystore = FaultInjectingKeystore(
            values: [legacyIdentifier: legacyKey]
        )
        let migrator = KeystoreMigrator(
            sourceVersion: .version1,
            destinationVersion: .version2,
            keystore: keystore
        )
        try migrator.switchVersion()
        migrator.deleteKey(for: legacyIdentifier)
        migrator.save(key: destinationKey, for: destinationIdentifier)
        try migrator.prepare()

        return (
            keystore: keystore,
            legacyIdentifier: legacyIdentifier,
            destinationIdentifier: destinationIdentifier,
            legacyKey: legacyKey,
            destinationKey: destinationKey
        )
    }

    private func rewriteCleanupJournal(
        in keystore: FaultInjectingKeystore,
        mutation: (inout [String: Any]) throws -> Void
    ) throws -> Data {
        let originalData = try XCTUnwrap(
            keystore.value(for: KeystoreMigrator.pendingCleanupIdentifier)
        )
        var journal = try XCTUnwrap(
            JSONSerialization.jsonObject(with: originalData) as? [String: Any]
        )
        try mutation(&journal)
        let rewrittenData = try JSONSerialization.data(
            withJSONObject: journal,
            options: [.sortedKeys]
        )
        try keystore.updateKey(
            rewrittenData,
            with: KeystoreMigrator.pendingCleanupIdentifier
        )

        return rewrittenData
    }

    private func legacyDeletionIdentifier(
        _ accountByte: UInt8
    ) throws -> String {
        let address = try SS58AddressFactory().address(
            fromAccountId: Data(repeating: accountByte, count: 32),
            type: 42
        )

        return fearless.KeystoreTag.secretKeyTagForAddress(address)
    }

    private func destinationMigrationIdentifier() -> String {
        fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(
            UUID().uuidString
        )
    }

    private func legacyCleanupJournalData(
        sourceVersion: UserStorageVersion,
        destinationVersion: UserStorageVersion,
        identifiersToRemove: [String],
        stagedIdentifiers: [String]
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "sourceVersion": sourceVersion.rawValue,
                "destinationVersion": destinationVersion.rawValue,
                "identifiersToRemove": identifiersToRemove,
                "stagedIdentifiers": stagedIdentifiers
            ],
            options: [.sortedKeys]
        )
    }

    private func assertCleanupFixtureIsFullyRetained(
        _ fixture: CleanupJournalFixture,
        expectedJournal: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            fixture.keystore.value(for: fixture.legacyIdentifier),
            fixture.legacyKey,
            file: file,
            line: line
        )
        XCTAssertEqual(
            fixture.keystore.value(for: fixture.destinationIdentifier),
            fixture.destinationKey,
            file: file,
            line: line
        )
        XCTAssertEqual(
            fixture.keystore.value(
                for: KeystoreMigrator.pendingCleanupIdentifier
            ),
            expectedJournal,
            file: file,
            line: line
        )
    }

    private func directCompatibilityModelURL(
        for version: UserStorageVersion
    ) throws -> URL {
        try XCTUnwrap(
            appBundle.url(
                forResource: version.rawValue,
                withExtension: "mom"
            ),
            "\(version.rawValue).mom must be copied into the application bundle root"
        )
    }

    private func model(for version: UserStorageVersion) throws -> NSManagedObjectModel {
        let url = try XCTUnwrap(
            version.modelURL(
                in: appBundle,
                legacyModelDirectory: UserStorageParams.modelDirectory
            ),
            "Missing model resource for \(version.rawValue)"
        )

        return try loadModel(at: url)
    }

    private func loadModel(at url: URL) throws -> NSManagedObjectModel {
        try XCTUnwrap(
            NSManagedObjectModel(contentsOf: url),
            "Unable to load Core Data model at \(url.path)"
        )
    }

    private func versionHashes(for model: NSManagedObjectModel) -> [String: String] {
        model.entityVersionHashesByName.mapValues { $0.base64EncodedString() }
    }

    private func storeChecksum(
        for model: NSManagedObjectModel,
        named name: String
    ) throws -> String {
        let url = testDirectory.appendingPathComponent(name)
        try createStore(at: url, model: model) { _ in }
        return try metadataChecksum(at: url)
    }

    private func metadataChecksum(at url: URL) throws -> String {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        )

        return try XCTUnwrap(
            metadata["NSStoreModelVersionChecksumKey"] as? String,
            "Store metadata is missing its model checksum"
        )
    }

    private func createStore(
        at url: URL,
        model: NSManagedObjectModel,
        populate: (NSManagedObjectContext) throws -> Void
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSSQLitePragmasOption: ["journal_mode": "WAL"],
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var populationError: Error?
        context.performAndWait {
            do {
                try populate(context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                populationError = error
            }
        }

        if let populationError {
            throw populationError
        }
    }

    private func useStore(
        at url: URL,
        model: NSManagedObjectModel,
        body: (NSManagedObjectContext) throws -> Void
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer {
            try? coordinator.remove(store)
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var bodyError: Error?
        context.performAndWait {
            do {
                try body(context)
            } catch {
                bodyError = error
            }
        }

        if let bodyError {
            throw bodyError
        }
    }

    private func insertVersion2WalletFixture(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let walletEntity = try XCTUnwrap(
            model.entitiesByName["CDMetaAccount"]
        )
        let firstWallet = NSManagedObject(
            entity: walletEntity,
            insertInto: context
        )
        firstWallet.setValue("v2-wallet-alpha", forKey: "metaId")
        firstWallet.setValue("Version 2 Alpha", forKey: "name")
        firstWallet.setValue(true, forKey: "isSelected")
        firstWallet.setValue(Int32(1), forKey: "order")
        firstWallet.setValue(
            hex(byte: 0x11, count: 32),
            forKey: "substrateAccountId"
        )
        firstWallet.setValue(
            Data(repeating: 0x12, count: 32),
            forKey: "substratePublicKey"
        )
        firstWallet.setValue(
            Int16(1),
            forKey: "substrateCryptoType"
        )

        let secondWallet = NSManagedObject(
            entity: walletEntity,
            insertInto: context
        )
        secondWallet.setValue("v2-wallet-beta", forKey: "metaId")
        secondWallet.setValue("Version 2 Beta", forKey: "name")
        secondWallet.setValue(false, forKey: "isSelected")
        secondWallet.setValue(Int32(2), forKey: "order")
        secondWallet.setValue(
            hex(byte: 0x21, count: 32),
            forKey: "substrateAccountId"
        )
        secondWallet.setValue(
            Data(repeating: 0x22, count: 32),
            forKey: "substratePublicKey"
        )
        secondWallet.setValue(
            Int16(0),
            forKey: "substrateCryptoType"
        )

        try insertVersion2ChainAccount(
            chainId: "kusama",
            accountId: hex(byte: 0x31, count: 32),
            publicKey: Data(repeating: 0x32, count: 32),
            cryptoType: 1,
            wallet: firstWallet,
            in: context,
            model: model
        )
        try insertVersion2ChainAccount(
            chainId: "polkadot",
            accountId: hex(byte: 0x41, count: 32),
            publicKey: Data(repeating: 0x42, count: 32),
            cryptoType: 0,
            wallet: firstWallet,
            in: context,
            model: model
        )
        try insertVersion2ChainAccount(
            chainId: "westend",
            accountId: hex(byte: 0x51, count: 32),
            publicKey: Data(repeating: 0x52, count: 32),
            cryptoType: 1,
            wallet: secondWallet,
            in: context,
            model: model
        )
    }

    private func insertVersion2ChainAccount(
        chainId: String,
        accountId: String,
        publicKey: Data,
        cryptoType: Int16,
        wallet: NSManagedObject,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let entity = try XCTUnwrap(
            model.entitiesByName["CDChainAccount"]
        )
        let chainAccount = NSManagedObject(
            entity: entity,
            insertInto: context
        )
        chainAccount.setValue(chainId, forKey: "chainId")
        chainAccount.setValue(accountId, forKey: "accountId")
        chainAccount.setValue(publicKey, forKey: "publicKey")
        chainAccount.setValue(cryptoType, forKey: "cryptoType")
        chainAccount.setValue(wallet, forKey: "metaAccount")
    }

    private func version2WalletFixtureSnapshots() -> [WalletSnapshot] {
        [
            WalletSnapshot(
                metaId: "v2-wallet-alpha",
                name: "Version 2 Alpha",
                substrateAccountId: hex(byte: 0x11, count: 32),
                substratePublicKey: Data(repeating: 0x12, count: 32),
                tonAddress: nil,
                tonPublicKey: nil,
                tonContractVersion: nil,
                assetsVisibility: [:],
                chainAccounts: [
                    ChainSnapshot(
                        chainId: "kusama",
                        accountId: hex(byte: 0x31, count: 32),
                        publicKey: Data(repeating: 0x32, count: 32),
                        cryptoType: 1,
                        ecosystem: nil
                    ),
                    ChainSnapshot(
                        chainId: "polkadot",
                        accountId: hex(byte: 0x41, count: 32),
                        publicKey: Data(repeating: 0x42, count: 32),
                        cryptoType: 0,
                        ecosystem: nil
                    )
                ]
            ),
            WalletSnapshot(
                metaId: "v2-wallet-beta",
                name: "Version 2 Beta",
                substrateAccountId: hex(byte: 0x21, count: 32),
                substratePublicKey: Data(repeating: 0x22, count: 32),
                tonAddress: nil,
                tonPublicKey: nil,
                tonContractVersion: nil,
                assetsVisibility: [:],
                chainAccounts: [
                    ChainSnapshot(
                        chainId: "westend",
                        accountId: hex(byte: 0x51, count: 32),
                        publicKey: Data(repeating: 0x52, count: 32),
                        cryptoType: 1,
                        ecosystem: nil
                    )
                ]
            )
        ]
    }

    private func insertLegacyWallets(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let regularWallet = try insertWallet(
            metaId: "regular-wallet",
            name: "Regular Wallet",
            in: context,
            model: model
        )
        regularWallet.setValue(hex(byte: 0x11, count: 32), forKey: "substrateAccountId")
        regularWallet.setValue(Data(repeating: 0x12, count: 32), forKey: "substratePublicKey")
        regularWallet.setValue(Int16(1), forKey: "substrateCryptoType")
        regularWallet.setValue(hex(byte: 0x15, count: 20), forKey: "ethereumAddress")
        regularWallet.setValue(Data(repeating: 0x16, count: 33), forKey: "ethereumPublicKey")
        regularWallet.setValue(Data(repeating: 0x13, count: 36), forKey: "tonAddress")
        regularWallet.setValue(Data(repeating: 0x14, count: 32), forKey: "tonPublicKey")
        regularWallet.setValue("v4R2", forKey: "tonContractVersion")

        try insertAssetVisibility(
            assetId: "polkadot-0",
            hidden: false,
            wallet: regularWallet,
            in: context,
            model: model
        )
        try insertAssetVisibility(
            assetId: "kusama-0",
            hidden: true,
            wallet: regularWallet,
            in: context,
            model: model
        )
        try insertChainAccount(
            chainId: "substrate-chain",
            accountId: hex(byte: 0x21, count: 32),
            publicKey: Data(repeating: 0x22, count: 32),
            cryptoType: 1,
            ecosystem: "substrate",
            wallet: regularWallet,
            in: context,
            model: model
        )
        try insertChainAccount(
            chainId: "ethereum-chain",
            accountId: hex(byte: 0x31, count: 20),
            publicKey: Data(repeating: 0x32, count: 33),
            cryptoType: 2,
            ecosystem: UniversalWalletEcosystem.evm.rawValue,
            wallet: regularWallet,
            in: context,
            model: model
        )

        let tonOnlyWallet = try insertWallet(
            metaId: "ton-only-wallet",
            name: "TON Only Wallet",
            in: context,
            model: model
        )
        tonOnlyWallet.setValue(Data(repeating: 0x41, count: 36), forKey: "tonAddress")
        tonOnlyWallet.setValue(Data(repeating: 0x42, count: 32), forKey: "tonPublicKey")
        tonOnlyWallet.setValue("v5R1", forKey: "tonContractVersion")
    }

    @discardableResult
    private func insertWallet(
        metaId: String,
        name: String,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> NSManagedObject {
        let entity = try XCTUnwrap(model.entitiesByName["CDMetaAccount"])
        let wallet = NSManagedObject(entity: entity, insertInto: context)
        wallet.setValue(metaId, forKey: "metaId")
        wallet.setValue(name, forKey: "name")
        wallet.setValue(metaId == "regular-wallet", forKey: "isSelected")
        wallet.setValue(Int32(metaId == "regular-wallet" ? 1 : 2), forKey: "order")
        wallet.setValue(false, forKey: "canExportEthereumMnemonic")
        wallet.setValue(false, forKey: "hasBackup")
        wallet.setValue(false, forKey: "zeroBalanceAssetsHidden")
        wallet.setValue(NSArray(), forKey: "favouriteChainIds")
        return wallet
    }

    private func insertCurrentWallet(
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) {
        guard let entity = model.entitiesByName["CDMetaAccount"] else {
            return XCTFail("Current model is missing CDMetaAccount")
        }

        let wallet = NSManagedObject(entity: entity, insertInto: context)
        wallet.setValue("current-wallet", forKey: "metaId")
        wallet.setValue("Current Wallet", forKey: "name")
        wallet.setValue(false, forKey: "isSelected")
        wallet.setValue(Int32(1), forKey: "order")
        wallet.setValue(false, forKey: "canExportEthereumMnemonic")
        wallet.setValue(false, forKey: "hasBackup")
        wallet.setValue(false, forKey: "zeroBalanceAssetsHidden")
        wallet.setValue(NSArray(), forKey: "favouriteChainIds")
        wallet.setValue(hex(byte: 0x51, count: 32), forKey: "substrateAccountId")
        wallet.setValue(Data(repeating: 0x52, count: 32), forKey: "substratePublicKey")
        wallet.setValue(Int16(1), forKey: "substrateCryptoType")
    }

    @discardableResult
    private func insertHistoricalWallet(
        metaId: String,
        name: String,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws -> NSManagedObject {
        let entity = try XCTUnwrap(
            model.entitiesByName["CDMetaAccount"]
        )
        let wallet = NSManagedObject(
            entity: entity,
            insertInto: context
        )
        wallet.setValue(metaId, forKey: "metaId")
        wallet.setValue(name, forKey: "name")
        wallet.setValue(false, forKey: "isSelected")
        wallet.setValue(Int32(1), forKey: "order")
        wallet.setValue(
            hex(byte: 0x71, count: 32),
            forKey: "substrateAccountId"
        )
        wallet.setValue(
            Data(repeating: 0x72, count: 32),
            forKey: "substratePublicKey"
        )
        wallet.setValue(
            Int16(1),
            forKey: "substrateCryptoType"
        )

        if entity.attributesByName[
            "canExportEthereumMnemonic"
        ] != nil {
            wallet.setValue(
                false,
                forKey: "canExportEthereumMnemonic"
            )
        }
        if entity.attributesByName["hasBackup"] != nil {
            wallet.setValue(false, forKey: "hasBackup")
        }
        if entity.attributesByName[
            "zeroBalanceAssetsHidden"
        ] != nil {
            wallet.setValue(
                false,
                forKey: "zeroBalanceAssetsHidden"
            )
        }

        return wallet
    }

    private func insertAssetVisibility(
        assetId: String,
        hidden: Bool,
        wallet: NSManagedObject,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let entity = try XCTUnwrap(model.entitiesByName["CDAssetVisibility"])
        let visibility = NSManagedObject(entity: entity, insertInto: context)
        visibility.setValue(assetId, forKey: "assetId")
        visibility.setValue(hidden, forKey: "hidden")
        visibility.setValue(wallet, forKey: "wallet")
    }

    private func insertChainAccount(
        chainId: String,
        accountId: String,
        publicKey: Data,
        cryptoType: Int16,
        ecosystem: String,
        wallet: NSManagedObject,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let entity = try XCTUnwrap(model.entitiesByName["CDChainAccount"])
        let chainAccount = NSManagedObject(entity: entity, insertInto: context)
        chainAccount.setValue(chainId, forKey: "chainId")
        chainAccount.setValue(accountId, forKey: "accountId")
        chainAccount.setValue(publicKey, forKey: "publicKey")
        chainAccount.setValue(cryptoType, forKey: "cryptoType")
        chainAccount.setValue(ecosystem, forKey: "ecosystem")
        chainAccount.setValue(wallet, forKey: "metaAccount")
    }

    private func insertPublicChainAccount(
        wallet: NSManagedObject,
        in context: NSManagedObjectContext,
        model: NSManagedObjectModel
    ) throws {
        let entity = try XCTUnwrap(model.entitiesByName["CDChainAccount"])
        let chainAccount = NSManagedObject(entity: entity, insertInto: context)
        chainAccount.setValue("ethereum-mainnet", forKey: "chainId")
        chainAccount.setValue(hex(byte: 0x61, count: 20), forKey: "accountId")
        chainAccount.setValue(Data(repeating: 0x62, count: 33), forKey: "publicKey")
        chainAccount.setValue(Int16(2), forKey: "cryptoType")
        chainAccount.setValue(true, forKey: "ethereumBased")
        chainAccount.setValue(wallet, forKey: "metaAccount")
    }

    private func walletSnapshots(
        from url: URL,
        model: NSManagedObjectModel
    ) throws -> [WalletSnapshot] {
        var snapshots: [WalletSnapshot] = []

        try useStore(at: url, model: model) { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            let wallets = try context.fetch(request)
            snapshots = wallets.map { wallet in
                let visibilityObjects =
                    (wallet.value(forKey: "assetsVisibility") as? NSSet)?
                    .allObjects as? [NSManagedObject] ?? []
                let visibility: [String: Bool] = Dictionary(
                    uniqueKeysWithValues: visibilityObjects.compactMap { object in
                        guard let assetId = object.value(forKey: "assetId") as? String else {
                            return nil
                        }

                        let hidden = (object.value(forKey: "hidden") as? NSNumber)?.boolValue ?? false
                        return (assetId, hidden)
                    }
                )

                let chainObjects =
                    (wallet.value(forKey: "chainAccounts") as? NSSet)?
                    .allObjects as? [NSManagedObject] ?? []
                let chains = chainObjects.compactMap { object -> ChainSnapshot? in
                    guard
                        let chainId = object.value(forKey: "chainId") as? String,
                        let accountId = object.value(forKey: "accountId") as? String,
                        let publicKey = object.value(forKey: "publicKey") as? Data
                    else {
                        return nil
                    }

                    let cryptoType = (object.value(forKey: "cryptoType") as? NSNumber)?.int16Value ?? 0
                    return ChainSnapshot(
                        chainId: chainId,
                        accountId: accountId,
                        publicKey: publicKey,
                        cryptoType: cryptoType,
                        ecosystem: object.value(forKey: "ecosystem") as? String
                    )
                }.sorted { $0.chainId < $1.chainId }

                return WalletSnapshot(
                    metaId: wallet.value(forKey: "metaId") as? String ?? "",
                    name: wallet.value(forKey: "name") as? String ?? "",
                    substrateAccountId: wallet.value(forKey: "substrateAccountId") as? String,
                    substratePublicKey: wallet.value(forKey: "substratePublicKey") as? Data,
                    tonAddress: wallet.value(forKey: "tonAddress") as? Data,
                    tonPublicKey: wallet.value(forKey: "tonPublicKey") as? Data,
                    tonContractVersion: wallet.value(forKey: "tonContractVersion") as? String,
                    assetsVisibility: visibility,
                    chainAccounts: chains
                )
            }.sorted { $0.metaId < $1.metaId }
        }

        return snapshots
    }

    private func makeUnknownModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "UnknownWallet"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let identifier = NSAttributeDescription()
        identifier.name = "identifier"
        identifier.attributeType = .stringAttributeType
        identifier.isOptional = true
        entity.properties = [identifier]
        model.entities = [entity]

        return model
    }

    private func storeFamilySnapshot(at url: URL) throws -> [String: Data] {
        let fileNames = try FileManager.default.contentsOfDirectory(
            atPath: url.deletingLastPathComponent().path
        ).filter { $0.hasPrefix(url.lastPathComponent) }

        return try Dictionary(
            uniqueKeysWithValues: fileNames.map { fileName in
                let fileURL = url.deletingLastPathComponent().appendingPathComponent(fileName)
                return (fileName, try Data(contentsOf: fileURL))
            }
        )
    }

    private func durableStoreSnapshot(at url: URL) throws -> [String: Data] {
        try storeFamilySnapshot(at: url).filter { fileName, _ in
            !fileName.hasSuffix("-shm")
        }
    }

    private func makeSyntheticScenarioDirectory(
        _ name: String
    ) throws -> URL {
        let url = testDirectory
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: false
        )
        return url
    }

    private func syntheticFamilyURL(
        _ storeURL: URL,
        suffix: String
    ) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }

    private func writeSyntheticStoreFamily(
        at url: URL,
        seed: UInt8
    ) throws {
        for (index, suffix) in
            CrashConsistentStoreReplacer.storeFamilySuffixes
            .enumerated() {
            try Data(
                repeating: seed &+ UInt8(index),
                count: 31 + index * 7
            ).write(
                to: syntheticFamilyURL(url, suffix: suffix),
                options: .atomic
            )
        }
    }

    private func syntheticStoreFamilySnapshot(
        at url: URL
    ) throws -> [String: Data] {
        var snapshot: [String: Data] = [:]

        for suffix in
            CrashConsistentStoreReplacer.storeFamilySuffixes {
            let memberURL = syntheticFamilyURL(
                url,
                suffix: suffix
            )
            guard
                FileManager.default.fileExists(
                    atPath: memberURL.path
                )
            else {
                continue
            }

            snapshot[suffix] = try Data(contentsOf: memberURL)
        }

        return snapshot
    }

    private func replaceSyntheticStoreFamily(
        at targetURL: URL,
        with sourceURL: URL
    ) throws {
        for suffix in
            CrashConsistentStoreReplacer.storeFamilySuffixes {
            let targetMemberURL = syntheticFamilyURL(
                targetURL,
                suffix: suffix
            )
            if FileManager.default.fileExists(
                atPath: targetMemberURL.path
            ) {
                try FileManager.default.removeItem(
                    at: targetMemberURL
                )
            }
        }

        for suffix in
            CrashConsistentStoreReplacer.storeFamilySuffixes {
            let sourceMemberURL = syntheticFamilyURL(
                sourceURL,
                suffix: suffix
            )
            guard
                FileManager.default.fileExists(
                    atPath: sourceMemberURL.path
                )
            else {
                continue
            }

            try FileManager.default.copyItem(
                at: sourceMemberURL,
                to: syntheticFamilyURL(
                    targetURL,
                    suffix: suffix
                )
            )
        }
    }

    private func executeSQLite(
        _ sql: String,
        at url: URL
    ) throws {
        let database = try openSQLite(at: url)
        defer {
            sqlite3_close(database)
        }
        try executeSQLite(sql, database: database)
    }

    private func executeSQLite(
        _ sql: String,
        database: OpaquePointer
    ) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(
            database,
            sql,
            nil,
            nil,
            &errorMessage
        )
        defer {
            sqlite3_free(errorMessage)
        }

        guard result == SQLITE_OK else {
            let description = errorMessage.map {
                String(cString: $0)
            } ?? "Unknown SQLite error"
            throw NSError(
                domain: "UserStorageCompatibilityMigrationTests.SQLite",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: description]
            )
        }
    }

    private func updateSQLiteBlob(
        _ data: Data,
        column: String,
        at url: URL
    ) throws {
        let allowedColumns: Set<String> = [
            "ZASSETFILTEROPTIONS",
            "ZASSETKEYSORDER",
            "ZFAVOURITECHAINIDS",
            "ZUNUSEDCHAINIDS"
        ]
        guard allowedColumns.contains(column) else {
            throw NSError(
                domain:
                "UserStorageCompatibilityMigrationTests.SQLite",
                code: Int(SQLITE_MISUSE),
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "Unexpected SQLite test column"
                ]
            )
        }

        let database = try openSQLite(at: url)
        defer {
            sqlite3_close(database)
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(
            database,
            "UPDATE ZCDMETAACCOUNT SET \(column) = ?1",
            -1,
            &statement,
            nil
        )
        guard prepareResult == SQLITE_OK, let statement else {
            throw NSError(
                domain:
                "UserStorageCompatibilityMigrationTests.SQLite",
                code: Int(prepareResult)
            )
        }
        defer {
            sqlite3_finalize(statement)
        }

        let sqliteTransient = unsafeBitCast(
            -1,
            to: sqlite3_destructor_type.self
        )
        let bindResult = data.withUnsafeBytes {
            rawBuffer in

            sqlite3_bind_blob(
                statement,
                1,
                rawBuffer.baseAddress,
                Int32(rawBuffer.count),
                sqliteTransient
            )
        }
        guard bindResult == SQLITE_OK else {
            throw NSError(
                domain:
                "UserStorageCompatibilityMigrationTests.SQLite",
                code: Int(bindResult)
            )
        }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE else {
            throw NSError(
                domain:
                "UserStorageCompatibilityMigrationTests.SQLite",
                code: Int(stepResult)
            )
        }
    }

    private func openSQLite(at url: URL) throws -> OpaquePointer {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READWRITE,
            nil
        )

        guard result == SQLITE_OK, let database else {
            defer {
                if let database {
                    sqlite3_close(database)
                }
            }
            throw NSError(
                domain: "UserStorageCompatibilityMigrationTests.SQLite",
                code: Int(result),
                userInfo: [
                    NSLocalizedDescriptionKey: "Unable to open SQLite store"
                ]
            )
        }

        return database
    }

    private func hex(byte: UInt8, count: Int) -> String {
        Data(repeating: byte, count: count)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private enum UserStorageCommitTestError: Error, Equatable {
    case storeReplacementFailed
    case keystoreFinalizeFailed
    case settingsFinalizeFailed
}

private enum UserStorageCommitEvent: Equatable {
    case keystorePrepare
    case settingsPrepare
    case storeReplacement
    case keystoreFinalize
    case settingsFinalize
}

private final class UserStorageCommitRecorder {
    private let lock = NSLock()
    private var recordedEvents: [UserStorageCommitEvent] = []

    var events: [UserStorageCommitEvent] {
        lock.with { recordedEvents }
    }

    func record(_ event: UserStorageCommitEvent) {
        lock.with {
            recordedEvents.append(event)
        }
    }
}

private final class RecordingKeystoreMigrator: KeystoreMigrating {
    private let recorder: UserStorageCommitRecorder
    private let finalizeError: Error?

    init(
        recorder: UserStorageCommitRecorder,
        finalizeError: Error? = nil
    ) {
        self.recorder = recorder
        self.finalizeError = finalizeError
    }

    func switchVersion() throws {}

    func fetchKey(for _: String) throws -> Data? {
        nil
    }

    func deleteKey(for _: String) {}

    func save(key _: Data, for _: String) {}

    func prepare() throws {
        recorder.record(.keystorePrepare)
    }

    func finalize() throws {
        recorder.record(.keystoreFinalize)

        if let finalizeError {
            throw finalizeError
        }
    }
}

private final class MappingFinalizeFailureKeystoreMigrator:
    KeystoreMigrating {
    private let migrator: KeystoreMigrating
    private let mappedError: Error
    private(set) var underlyingFinalizeError: Error?

    init(
        migrator: KeystoreMigrating,
        mappedError: Error
    ) {
        self.migrator = migrator
        self.mappedError = mappedError
    }

    func switchVersion() throws {
        try migrator.switchVersion()
    }

    func fetchKey(for identifier: String) throws -> Data? {
        try migrator.fetchKey(for: identifier)
    }

    func deleteKey(for identifier: String) {
        migrator.deleteKey(for: identifier)
    }

    func save(key: Data, for identifier: String) {
        migrator.save(key: key, for: identifier)
    }

    func prepare() throws {
        try migrator.prepare()
    }

    func finalize() throws {
        do {
            try migrator.finalize()
        } catch {
            underlyingFinalizeError = error
            throw mappedError
        }
    }
}

private final class RecordingSettingsMigrator: SettingsMigrating {
    private let recorder: UserStorageCommitRecorder

    init(recorder: UserStorageCommitRecorder) {
        self.recorder = recorder
    }

    func switchVersion() throws {}

    func value(for _: String) -> Any? {
        nil
    }

    func remove(key _: String) {}

    func set(value _: Any, for _: String) {}

    func prepare() throws {
        recorder.record(.settingsPrepare)
    }

    func finalize() throws {
        recorder.record(.settingsFinalize)
    }
}

private final class CleanupJournalSettingsMigrator:
    SettingsMigrating {
    private let migrator: SettingsMigrator
    private let finalizeError: Error?

    init(
        sourceVersion: UserStorageVersion,
        destinationVersion: UserStorageVersion,
        settings: SettingsManagerProtocol,
        finalizeError: Error? = nil
    ) {
        migrator = SettingsMigrator(
            sourceVersion: sourceVersion,
            destinationVersion: destinationVersion,
            settings: settings
        )
        self.finalizeError = finalizeError
    }

    func switchVersion() throws {
        try migrator.switchVersion()
    }

    func value(for key: String) -> Any? {
        migrator.value(for: key)
    }

    func remove(key: String) {
        migrator.remove(key: key)
    }

    func set(value: Any, for key: String) {
        migrator.set(value: value, for: key)
    }

    func prepare() throws {
        migrator.remove(
            key: SettingsKey.selectedAccount.rawValue
        )
        migrator.remove(
            key: SettingsKey.selectedConnection.rawValue
        )
        try migrator.prepare()
    }

    func finalize() throws {
        if let finalizeError {
            throw finalizeError
        }

        try migrator.finalize()
    }
}

private final class FaultInjectingKeystore: KeystoreProtocol {
    enum Operation: Hashable {
        case add(String)
        case update(String)
        case fetch(String)
        case check(String)
        case delete(String)
    }

    enum Error: Swift.Error, Equatable {
        case injected(Operation)
    }

    var failures = Set<Operation>()
    private var values: [String: Data]

    init(values: [String: Data] = [:]) {
        self.values = values
    }

    func value(for identifier: String) -> Data? {
        values[identifier]
    }

    func addKey(
        _ key: Data,
        with identifier: String
    ) throws {
        try throwIfNeeded(.add(identifier))

        guard values[identifier] == nil else {
            throw KeystoreError.duplicatedItem
        }

        values[identifier] = key
    }

    func updateKey(
        _ key: Data,
        with identifier: String
    ) throws {
        try throwIfNeeded(.update(identifier))

        guard values[identifier] != nil else {
            throw KeystoreError.noKeyFound
        }

        values[identifier] = key
    }

    func fetchKey(for identifier: String) throws -> Data {
        try throwIfNeeded(.fetch(identifier))

        guard let value = values[identifier] else {
            throw KeystoreError.noKeyFound
        }

        return value
    }

    func checkKey(for identifier: String) throws -> Bool {
        try throwIfNeeded(.check(identifier))
        return values[identifier] != nil
    }

    func deleteKey(for identifier: String) throws {
        try throwIfNeeded(.delete(identifier))

        guard values.removeValue(forKey: identifier) != nil else {
            throw KeystoreError.noKeyFound
        }
    }

    private func throwIfNeeded(_ operation: Operation) throws {
        if failures.contains(operation) {
            throw Error.injected(operation)
        }
    }
}
