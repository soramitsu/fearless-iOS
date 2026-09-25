import Foundation
import SQLite3
import XCTest
@testable import fearless

final class CrashConsistentStoreReplacerResourceLimitTests:
    XCTestCase
{
    private var rootURL: URL!
    private var storeURL: URL!
    private var stagedStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CrashConsistentStoreResourceLimits-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: false
        )
        storeURL = rootURL.appendingPathComponent("Live.sqlite")
        stagedStoreURL = rootURL.appendingPathComponent("Staged.sqlite")
    }

    override func tearDownWithError() throws {
        if let rootURL {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try super.tearDownWithError()
    }

    func testSQLiteQuickCheckAcceptsValidStoreAndRejectsCorruption() throws {
        let validStoreURL = rootURL.appendingPathComponent("Valid.sqlite")
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(validStoreURL.path, &database), SQLITE_OK)
        guard let database else {
            return XCTFail("Unable to create SQLite test store")
        }
        XCTAssertEqual(
            sqlite3_exec(
                database,
                "CREATE TABLE example (value INTEGER); INSERT INTO example VALUES (1);",
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )
        XCTAssertEqual(sqlite3_close(database), SQLITE_OK)

        XCTAssertNoThrow(
            try SQLiteStoreQuickChecker.validate(storeURL: validStoreURL)
        )

        let corruptStoreURL = rootURL.appendingPathComponent("Corrupt.sqlite")
        try Data("not a sqlite store".utf8).write(to: corruptStoreURL)

        XCTAssertThrowsError(
            try SQLiteStoreQuickChecker.validate(storeURL: corruptStoreURL)
        )
    }

    func testReplaceStore_whenMainFileExceedsLimit_rejectsBeforeCapacityOrMutation() throws {
        let maximum =
            CrashConsistentStoreReplacer
                .defaultMaximumStoreFamilyByteCount
        let oversizedByteCount = maximum + 1
        try Data().write(to: storeURL)
        let handle = try FileHandle(forWritingTo: storeURL)
        try handle.truncate(atOffset: oversizedByteCount)
        try handle.close()
        try Data([0x03]).write(to: stagedStoreURL)

        var capacityInspectionCount = 0
        var replacementCount = 0
        var boundaries: [CrashConsistentStoreReplacementBoundary] = []
        let replacer = makeReplacer(
            maximumStoreFamilyByteCount: maximum,
            availableCapacityProvider: { _ in
                capacityInspectionCount += 1
                return UInt64.max
            },
            storeReplacer: { _, _ in
                replacementCount += 1
            },
            boundaryHook: {
                boundaries.append($0)
            }
        )

        XCTAssertThrowsError(
            try replacer.replaceStore(
                with: stagedStoreURL,
                validateDestination: { _ in }
            )
        ) { error in
            guard
                case let .storeFamilyTooLarge(
                    actual,
                    reportedMaximum
                ) =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(actual, oversizedByteCount)
            XCTAssertEqual(reportedMaximum, maximum)
        }

        XCTAssertEqual(capacityInspectionCount, 0)
        XCTAssertEqual(replacementCount, 0)
        XCTAssertTrue(boundaries.isEmpty)
        XCTAssertFalse(replacer.hasPendingTransaction)
        let attributes = try FileManager.default
            .attributesOfItem(atPath: storeURL.path)
        XCTAssertEqual(
            (attributes[.size] as? NSNumber)?.uint64Value,
            oversizedByteCount
        )
    }

    func testReplaceStore_whenAggregateFamilyExceedsLimit_rejectsBeforeMutation() throws {
        try Data([0x01, 0x02]).write(to: storeURL)
        try Data([0x03, 0x04]).write(
            to: familyURL(storeURL, suffix: "-wal")
        )
        try Data([0x05]).write(to: stagedStoreURL)

        var replacementCount = 0
        let replacer = makeReplacer(
            maximumStoreFamilyByteCount: 3,
            storeReplacer: { _, _ in
                replacementCount += 1
            }
        )

        XCTAssertThrowsError(
            try replacer.replaceStore(
                with: stagedStoreURL,
                validateDestination: { _ in }
            )
        ) { error in
            guard
                case let .storeFamilyTooLarge(
                    actual,
                    reportedMaximum
                ) =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(actual, 4)
            XCTAssertEqual(reportedMaximum, 3)
        }

        XCTAssertEqual(replacementCount, 0)
        XCTAssertFalse(replacer.hasPendingTransaction)
    }

    func testReplaceStore_whenCapacityIsOneByteShort_rejectsBeforeTransactionMutation() throws {
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: storeURL)
        try Data([0x05, 0x06]).write(to: stagedStoreURL)

        var replacementCount = 0
        var boundaries: [CrashConsistentStoreReplacementBoundary] = []
        let replacer = makeReplacer(
            maximumStoreFamilyByteCount: 16,
            minimumFreeStorageReserveByteCount: 3,
            availableCapacityProvider: { _ in 6 },
            storeReplacer: { _, _ in
                replacementCount += 1
            },
            boundaryHook: {
                boundaries.append($0)
            }
        )

        XCTAssertThrowsError(
            try replacer.replaceStore(
                with: stagedStoreURL,
                validateDestination: { _ in }
            )
        ) { error in
            guard
                case let .insufficientStorageCapacity(required, available) =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(required, 7)
            XCTAssertEqual(available, 6)
        }

        XCTAssertEqual(replacementCount, 0)
        XCTAssertTrue(boundaries.isEmpty)
        XCTAssertFalse(replacer.hasPendingTransaction)
    }

    func testReplaceStore_whenFamilyAndCapacityAreExactBoundaries_succeeds() throws {
        let original = Data([0x01, 0x02, 0x03, 0x04])
        let replacement = Data([0x05, 0x06, 0x07, 0x08])
        try original.write(to: storeURL)
        try replacement.write(to: stagedStoreURL)

        let replacer = makeReplacer(
            maximumStoreFamilyByteCount: 4,
            minimumFreeStorageReserveByteCount: 3,
            availableCapacityProvider: { _ in 7 }
        )

        try replacer.replaceStore(
            with: stagedStoreURL,
            validateDestination: { _ in }
        )

        XCTAssertEqual(try Data(contentsOf: storeURL), replacement)
        XCTAssertFalse(replacer.hasPendingTransaction)
    }

    func testReplaceStore_whenCapacityRequirementOverflows_rejectsBeforeMutation() throws {
        try Data([0x01]).write(to: storeURL)
        try Data([0x02]).write(to: stagedStoreURL)

        var replacementCount = 0
        let replacer = makeReplacer(
            maximumStoreFamilyByteCount: 1,
            minimumFreeStorageReserveByteCount: UInt64.max,
            availableCapacityProvider: { _ in UInt64.max },
            storeReplacer: { _, _ in
                replacementCount += 1
            }
        )

        XCTAssertThrowsError(
            try replacer.replaceStore(
                with: stagedStoreURL,
                validateDestination: { _ in }
            )
        ) { error in
            guard
                case .storeFamilySizeOverflow =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(replacementCount, 0)
        XCTAssertFalse(replacer.hasPendingTransaction)
    }

    func testCommittedRecovery_whenValidationCopyLacksSpace_preservesTransactionForRetry() throws {
        let original = Data([0x10, 0x11, 0x12])
        let replacement = Data([0x20, 0x21, 0x22])
        try original.write(to: storeURL)
        try replacement.write(to: stagedStoreURL)

        let interrupted = makeReplacer(
            maximumStoreFamilyByteCount: 3,
            minimumFreeStorageReserveByteCount: 0,
            availableCapacityProvider: { _ in UInt64.max },
            boundaryHook: { boundary in
                if boundary == .committedMarkerPersisted {
                    throw CrashConsistentStoreReplacementInterruption
                        .simulatedProcessDeath
                }
            }
        )

        XCTAssertThrowsError(
            try interrupted.replaceStore(
                with: stagedStoreURL,
                validateDestination: { _ in }
            )
        ) { error in
            guard
                error is CrashConsistentStoreReplacementInterruption
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(interrupted.hasPendingTransaction)
        XCTAssertEqual(try Data(contentsOf: storeURL), replacement)

        let capacityBlocked = makeReplacer(
            maximumStoreFamilyByteCount: 3,
            minimumFreeStorageReserveByteCount: 0,
            availableCapacityProvider: { _ in 2 }
        )
        XCTAssertThrowsError(
            try capacityBlocked.reconcile(
                validateCommittedStore: { _ in }
            )
        ) { error in
            guard
                case let .insufficientStorageCapacity(required, available) =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(required, 3)
            XCTAssertEqual(available, 2)
        }
        XCTAssertTrue(capacityBlocked.hasPendingTransaction)
        XCTAssertEqual(try Data(contentsOf: storeURL), replacement)

        let recovered = makeReplacer(
            maximumStoreFamilyByteCount: 3,
            minimumFreeStorageReserveByteCount: 0,
            availableCapacityProvider: { _ in 3 }
        )
        try recovered.reconcile(validateCommittedStore: { _ in })

        XCTAssertFalse(recovered.hasPendingTransaction)
        XCTAssertEqual(try Data(contentsOf: storeURL), replacement)
    }

    func testPrivateCopy_whenSparseSourceExceedsLimit_rejectsBeforeCapacityOrCopy() throws {
        let maximum =
            CrashConsistentStoreReplacer
                .defaultMaximumStoreFamilyByteCount
        let oversizedByteCount = maximum + 1
        try Data().write(to: storeURL)
        let handle = try FileHandle(forWritingTo: storeURL)
        try handle.truncate(atOffset: oversizedByteCount)
        try handle.close()

        var capacityInspectionCount = 0
        XCTAssertThrowsError(
            try SQLiteStoreFamilyCopier.copy(
                from: storeURL,
                to: stagedStoreURL,
                includingSharedMemory: false,
                fileManager: .default,
                limits: SQLiteStoreFamilyCopyLimits(
                    maximumFamilyByteCount: maximum,
                    minimumFreeStorageReserveByteCount: 0
                ),
                availableCapacityProvider: { _ in
                    capacityInspectionCount += 1
                    return UInt64.max
                }
            )
        ) { error in
            guard
                case let .storeFamilyTooLarge(
                    actual,
                    reportedMaximum
                ) =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(actual, oversizedByteCount)
            XCTAssertEqual(reportedMaximum, maximum)
        }

        XCTAssertEqual(capacityInspectionCount, 0)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: stagedStoreURL.path
            )
        )
    }

    func testPrivateCopy_whenCapacityIsInsufficient_rejectsBeforeFirstMember() throws {
        try Data([0x01, 0x02, 0x03]).write(to: storeURL)

        XCTAssertThrowsError(
            try SQLiteStoreFamilyCopier.copy(
                from: storeURL,
                to: stagedStoreURL,
                includingSharedMemory: false,
                fileManager: .default,
                limits: SQLiteStoreFamilyCopyLimits(
                    maximumFamilyByteCount: 3,
                    minimumFreeStorageReserveByteCount: 2
                ),
                availableCapacityProvider: { _ in 4 }
            )
        ) { error in
            guard
                case let .insufficientStorageCapacity(required, available) =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(required, 5)
            XCTAssertEqual(available, 4)
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: stagedStoreURL.path
            )
        )
    }

    func testPrivateCopy_whenSourceMainIsSymlink_rejectsWithoutFollowingIt() throws {
        let outsideURL = rootURL.appendingPathComponent("Outside.sqlite")
        try Data([0x01]).write(to: outsideURL)
        try FileManager.default.createSymbolicLink(
            at: storeURL,
            withDestinationURL: outsideURL
        )

        XCTAssertThrowsError(
            try SQLiteStoreFamilyCopier.copy(
                from: storeURL,
                to: stagedStoreURL,
                includingSharedMemory: false,
                fileManager: .default,
                limits: SQLiteStoreFamilyCopyLimits(
                    maximumFamilyByteCount: 1,
                    minimumFreeStorageReserveByteCount: 0
                ),
                availableCapacityProvider: { _ in 1 }
            )
        ) { error in
            guard
                case .unsafeFile =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: stagedStoreURL.path
            )
        )
    }

    func testPrivateCopy_whenDestinationHasOrphanSidecar_rejectsBeforeMainCopy() throws {
        try Data([0x01]).write(to: storeURL)
        let orphanDestinationWAL = familyURL(
            stagedStoreURL,
            suffix: "-wal"
        )
        try Data([0xA5]).write(to: orphanDestinationWAL)

        XCTAssertThrowsError(
            try SQLiteStoreFamilyCopier.copy(
                from: storeURL,
                to: stagedStoreURL,
                includingSharedMemory: false,
                fileManager: .default,
                limits: SQLiteStoreFamilyCopyLimits(
                    maximumFamilyByteCount: 1,
                    minimumFreeStorageReserveByteCount: 0
                ),
                availableCapacityProvider: { _ in 1 }
            )
        ) { error in
            guard
                case .unsafeFile =
                error as? CrashConsistentStoreReplacementError
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: stagedStoreURL.path
            )
        )
        XCTAssertEqual(
            try Data(contentsOf: orphanDestinationWAL),
            Data([0xA5])
        )
    }

    func testPrivateCopy_atExactAggregateAndCapacityBoundary_copiesDurableMembersButNotSharedMemory() throws {
        try Data([0x01, 0x02]).write(to: storeURL)
        try Data([0x03]).write(
            to: familyURL(storeURL, suffix: "-wal")
        )
        try Data([0x04]).write(
            to: familyURL(storeURL, suffix: "-shm")
        )
        try Data([0x05]).write(
            to: familyURL(storeURL, suffix: "-journal")
        )

        try SQLiteStoreFamilyCopier.copy(
            from: storeURL,
            to: stagedStoreURL,
            includingSharedMemory: false,
            fileManager: .default,
            limits: SQLiteStoreFamilyCopyLimits(
                maximumFamilyByteCount: 4,
                minimumFreeStorageReserveByteCount: 2
            ),
            availableCapacityProvider: { _ in 6 }
        )

        XCTAssertEqual(
            try Data(contentsOf: stagedStoreURL),
            Data([0x01, 0x02])
        )
        XCTAssertEqual(
            try Data(
                contentsOf: familyURL(
                    stagedStoreURL,
                    suffix: "-wal"
                )
            ),
            Data([0x03])
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: familyURL(
                    stagedStoreURL,
                    suffix: "-shm"
                ).path
            )
        )
        XCTAssertEqual(
            try Data(
                contentsOf: familyURL(
                    stagedStoreURL,
                    suffix: "-journal"
                )
            ),
            Data([0x05])
        )
    }

    private func makeReplacer(
        maximumStoreFamilyByteCount: UInt64,
        minimumFreeStorageReserveByteCount: UInt64 = 0,
        availableCapacityProvider: @escaping (URL) throws -> UInt64 = {
            _ in UInt64.max
        },
        storeReplacer: ((URL, URL) throws -> Void)? = nil,
        boundaryHook: @escaping (
            CrashConsistentStoreReplacementBoundary
        ) throws -> Void = { _ in }
    ) -> CrashConsistentStoreReplacer {
        CrashConsistentStoreReplacer(
            storeURL: storeURL,
            fileManager: .default,
            storeReplacer: storeReplacer ?? replaceMainStore,
            boundaryHook: boundaryHook,
            maximumStoreFamilyByteCount:
            maximumStoreFamilyByteCount,
            minimumFreeStorageReserveByteCount:
            minimumFreeStorageReserveByteCount,
            availableCapacityProvider:
            availableCapacityProvider
        )
    }

    private func replaceMainStore(
        targetURL: URL,
        sourceURL: URL
    ) throws {
        try FileManager.default.removeItem(at: targetURL)
        try FileManager.default.copyItem(
            at: sourceURL,
            to: targetURL
        )
    }

    private func familyURL(
        _ storeURL: URL,
        suffix: String
    ) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }
}
