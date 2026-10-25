import XCTest
@testable import fearless

/// A store that is set aside must stay on the device byte for byte: nothing
/// here may delete, replace or rewrite a store file, whatever interrupts it.
final class RetainedStoreSetAsideTests: XCTestCase {
    private static let rootName = "TestStoreRetained"
    private static let markerFileName = "set-aside-transaction"
    private static let markerTemporaryFileName = "set-aside-transaction.pending"

    private var testDirectory: URL!
    private var storeURL: URL!

    private var rootURL: URL {
        testDirectory.appendingPathComponent(Self.rootName, isDirectory: true)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetainedStoreSetAsideTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        storeURL = testDirectory.appendingPathComponent("SubstrateDataModel.sqlite")
    }

    override func tearDownWithError() throws {
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }

        try super.tearDownWithError()
    }

    // MARK: - Moving

    func testSetAside_movesEveryFamilyMemberUnchangedAndLeavesNothingInstalled() throws {
        let family = try installFamily(label: "original")
        let neighbours = try installNeighbours()
        let setAside = makeSetAside()

        let archiveURL = try XCTUnwrap(try setAside.setAside())

        XCTAssertEqual(archiveURL.deletingLastPathComponent().path, rootURL.path)
        XCTAssertNotNil(UUID(uuidString: archiveURL.lastPathComponent))
        XCTAssertEqual(try directorySnapshot(archiveURL), family)
        XCTAssertTrue(try installedFamily().isEmpty)
        XCTAssertEqual(try snapshot(of: neighbours.keys), neighbours)
        XCTAssertFalse(setAside.hasPendingTransaction)
        XCTAssertEqual(try setAside.retainedArchiveURLs().map(\.path), [archiveURL.path])
    }

    func testSetAside_whenOnlySidecarsAreInstalled_movesThemToo() throws {
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        try Data("orphan-wal".utf8).write(to: walURL)

        let archiveURL = try XCTUnwrap(try makeSetAside().setAside())

        XCTAssertEqual(
            try directorySnapshot(archiveURL),
            [walURL.lastPathComponent: Data("orphan-wal".utf8)]
        )
        XCTAssertTrue(try installedFamily().isEmpty)
    }

    func testSetAside_whenNothingIsInstalled_returnsNilAndCreatesNothing() throws {
        let neighbours = try installNeighbours()
        let setAside = makeSetAside()

        XCTAssertNil(try setAside.setAside())
        XCTAssertNil(try setAside.reconcile())

        XCTAssertFalse(FileManager.default.fileExists(atPath: rootURL.path))
        XCTAssertEqual(try snapshot(of: neighbours.keys), neighbours)
        XCTAssertTrue(try setAside.retainedArchiveURLs().isEmpty)
    }

    func testSetAside_movesASymbolicLinkItselfAndNeverItsTarget() throws {
        let targetURL = testDirectory.appendingPathComponent("UserDataModel.sqlite")
        try Data("wallet-store-must-not-move".utf8).write(to: targetURL)
        try FileManager.default.createSymbolicLink(at: storeURL, withDestinationURL: targetURL)

        let archiveURL = try XCTUnwrap(try makeSetAside().setAside())

        let archivedLinkURL = archiveURL.appendingPathComponent(storeURL.lastPathComponent)
        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(atPath: archivedLinkURL.path),
            targetURL.path
        )
        XCTAssertEqual(try Data(contentsOf: targetURL), Data("wallet-store-must-not-move".utf8))
        XCTAssertTrue(try installedFamily().isEmpty)
    }

    func testSetAside_keepsEveryEarlierArchive() throws {
        let setAside = makeSetAside()
        var archives: [(URL, [String: Data])] = []

        for index in 0 ..< 3 {
            let family = try installFamily(label: "generation-\(index)")
            archives.append((try XCTUnwrap(try setAside.setAside()), family))
        }

        XCTAssertEqual(Set(archives.map(\.0.path)).count, 3)
        for (archiveURL, family) in archives {
            XCTAssertEqual(try directorySnapshot(archiveURL), family)
        }
        XCTAssertEqual(
            Set(try setAside.retainedArchiveURLs().map(\.path)),
            Set(archives.map(\.0.path))
        )
    }

    func testRetainedArchives_stayInDeviceBackups() throws {
        try installFamily(label: "backed-up")

        let archiveURL = try XCTUnwrap(try makeSetAside().setAside())

        for url in [rootURL, archiveURL] {
            let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            XCTAssertNotEqual(values.isExcludedFromBackup, true, url.lastPathComponent)
        }
    }

    // MARK: - Refusing

    func testSetAside_neverRefusesBecauseOfHowManyArchivesExist() throws {
        // Refusing would leave the store installed and the app unable to
        // open; every earlier archive is still kept.
        let setAside = makeSetAside()
        var archives: [(URL, [String: Data])] = []
        for index in 0 ..< 12 {
            let family = try installFamily(label: "generation-\(index)")
            archives.append((try XCTUnwrap(try setAside.setAside()), family))
            XCTAssertTrue(try installedFamily().isEmpty)
        }

        XCTAssertFalse(setAside.hasPendingTransaction)
        XCTAssertEqual(try setAside.retainedArchiveURLs().count, archives.count)
        for (archiveURL, family) in archives {
            XCTAssertEqual(try directorySnapshot(archiveURL), family)
        }
    }

    func testSetAside_whenRootIsNotADirectory_throwsAndLeavesEverythingUntouched() throws {
        let installed = try installFamily(label: "blocked")
        try Data("not-a-directory".utf8).write(to: rootURL)
        let setAside = makeSetAside()

        // Nothing can be pending there, so a launch is never stopped by it.
        XCTAssertFalse(setAside.hasPendingTransaction)
        XCTAssertNil(try setAside.reconcile())
        XCTAssertEqual(try installedFamily(), installed)

        XCTAssertThrowsError(try setAside.setAside()) { error in
            guard
                let setAsideError = error as? RetainedStoreSetAsideError,
                case .unsafeDirectory = setAsideError
            else {
                return XCTFail("Expected unsafeDirectory, got \(error)")
            }
        }

        XCTAssertEqual(try installedFamily(), installed)
        XCTAssertEqual(try Data(contentsOf: rootURL), Data("not-a-directory".utf8))
    }

    // MARK: - Interruption

    func testSetAside_whenProcessDiesAtEveryBoundary_thenRelaunchKeepsEveryByteInOneArchive() throws {
        var boundaries: [RetainedStoreSetAsideBoundary] = []
        try installFamily(label: "recording")
        _ = try makeSetAside(boundaryHook: { boundaries.append($0) }).setAside()
        XCTAssertEqual(
            boundaries,
            [
                .markerPersisted,
                .familyMemberMoved(""),
                .familyMemberMoved("-wal"),
                .familyMemberMoved("-shm"),
                .familyMemberMoved("-journal"),
                .markerRemoved
            ]
        )

        for (boundaryIndex, boundary) in boundaries.enumerated() {
            try XCTContext.runActivity(named: "dies at \(boundary)") { _ in
                try resetTestDirectory()
                let family = try installFamily(label: "boundary-\(boundaryIndex)")
                let neighbours = try installNeighbours()
                var crossedBoundaryCount = 0
                let interrupted = makeSetAside(boundaryHook: { _ in
                    defer { crossedBoundaryCount += 1 }
                    guard crossedBoundaryCount == boundaryIndex else { return }
                    throw RetainedStoreSetAsideInterruption.simulatedProcessDeath
                })

                XCTAssertThrowsError(try interrupted.setAside()) { error in
                    XCTAssertTrue(error is RetainedStoreSetAsideInterruption, "\(error)")
                }
                XCTAssertEqual(try everyFamilyByte(), family, "a byte was lost at the interruption")

                let relaunched = makeSetAside()
                XCTAssertEqual(relaunched.hasPendingTransaction, boundary != .markerRemoved)
                try relaunched.reconcile()

                XCTAssertTrue(try installedFamily().isEmpty)
                XCTAssertFalse(relaunched.hasPendingTransaction)
                let archiveURL = try XCTUnwrap(try relaunched.retainedArchiveURLs().first)
                XCTAssertEqual(try relaunched.retainedArchiveURLs().count, 1)
                XCTAssertEqual(try directorySnapshot(archiveURL), family)
                XCTAssertEqual(try snapshot(of: neighbours.keys), neighbours)

                // A second relaunch finds nothing left to do.
                XCTAssertNil(try makeSetAside().reconcile())
                XCTAssertEqual(try directorySnapshot(archiveURL), family)
            }
        }
    }

    func testReconcile_whenAStoreAppearedBesideAPendingMove_thenKeepsBothInSeparateArchives() throws {
        let family = try installFamily(label: "previous")
        var crossedBoundaryCount = 0
        let interrupted = makeSetAside(boundaryHook: { _ in
            defer { crossedBoundaryCount += 1 }
            // Dies after the marker and the main store file.
            guard crossedBoundaryCount == 1 else { return }
            throw RetainedStoreSetAsideInterruption.simulatedProcessDeath
        })
        XCTAssertThrowsError(try interrupted.setAside())
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        try Data("newer-store".utf8).write(to: storeURL)

        let relaunched = makeSetAside()
        let newestArchiveURL = try XCTUnwrap(try relaunched.reconcile())

        XCTAssertTrue(try installedFamily().isEmpty)
        XCTAssertFalse(relaunched.hasPendingTransaction)
        let archiveURLs = try relaunched.retainedArchiveURLs()
        XCTAssertEqual(archiveURLs.count, 2)
        XCTAssertEqual(
            try directorySnapshot(newestArchiveURL),
            [storeURL.lastPathComponent: Data("newer-store".utf8)]
        )
        let previousArchiveURL = try XCTUnwrap(archiveURLs.first { $0.path != newestArchiveURL.path })
        XCTAssertEqual(try directorySnapshot(previousArchiveURL), family)
    }

    func testReconcile_removesAnAbandonedPreparationButNeverADirectoryThatHoldsAnything() throws {
        let abandonedURL = rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let emptyURL = rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let foreignURL = rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        for url in [abandonedURL, emptyURL, foreignURL] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try Data().write(to: abandonedURL.appendingPathComponent(Self.markerTemporaryFileName))
        try Data("keep".utf8).write(to: foreignURL.appendingPathComponent("unexpected.txt"))
        try Data("keep".utf8).write(to: rootURL.appendingPathComponent("loose-file"))
        let installed = try installFamily(label: "untouched")
        let setAside = makeSetAside()

        XCTAssertFalse(setAside.hasPendingTransaction)
        XCTAssertNil(try setAside.reconcile())

        XCTAssertFalse(FileManager.default.fileExists(atPath: abandonedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyURL.path))
        XCTAssertEqual(try directorySnapshot(foreignURL), ["unexpected.txt": Data("keep".utf8)])
        XCTAssertEqual(try Data(contentsOf: rootURL.appendingPathComponent("loose-file")), Data("keep".utf8))
        XCTAssertEqual(try installedFamily(), installed)
        XCTAssertTrue(try setAside.retainedArchiveURLs().isEmpty)
    }

    func testReconcile_whenAMarkerIsDurable_thenFinishesTheMoveWhateverTheMarkerContains() throws {
        let family = try installFamily(label: "pending")
        let archiveURL = rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)
        try Data([0xFF, 0x00, 0xFE]).write(to: archiveURL.appendingPathComponent(Self.markerFileName))
        let setAside = makeSetAside()

        XCTAssertTrue(setAside.hasPendingTransaction)
        XCTAssertEqual(try setAside.reconcile()?.path, archiveURL.path)

        XCTAssertEqual(try directorySnapshot(archiveURL), family)
        XCTAssertTrue(try installedFamily().isEmpty)
        XCTAssertFalse(setAside.hasPendingTransaction)
    }

    // MARK: - Helpers

    private func makeSetAside(
        boundaryHook: @escaping (RetainedStoreSetAsideBoundary) throws -> Void = { _ in }
    ) -> RetainedStoreSetAside {
        RetainedStoreSetAside(
            storeURL: storeURL,
            rootName: Self.rootName,
            fileManager: .default,
            boundaryHook: boundaryHook
        )
    }

    @discardableResult
    private func installFamily(label: String) throws -> [String: Data] {
        var family: [String: Data] = [:]
        for suffix in RetainedStoreSetAside.storeFamilySuffixes {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            let data = Data("\(label)\(suffix)-bytes".utf8)
            try data.write(to: url)
            family[url.lastPathComponent] = data
        }

        return family
    }

    /// The wallet store lives in the same directory and must never move.
    private func installNeighbours() throws -> [String: Data] {
        var neighbours: [String: Data] = [:]
        for name in [
            "UserDataModel.sqlite",
            "UserDataModel.sqlite-wal",
            "UserDataModel.sqlite-shm",
            "SubstrateDataModel.sqlite.backup",
            "SubstrateDataModel.sqlite-wal2"
        ] {
            let data = Data("\(name)-must-not-move".utf8)
            try data.write(to: testDirectory.appendingPathComponent(name))
            neighbours[name] = data
        }

        return neighbours
    }

    private func installedFamily() throws -> [String: Data] {
        var family: [String: Data] = [:]
        for suffix in RetainedStoreSetAside.storeFamilySuffixes {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if (try? url.checkResourceIsReachable()) == true ||
                (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
                family[url.lastPathComponent] = try Data(contentsOf: url)
            }
        }

        return family
    }

    /// Installed and archived family files together; store names are unique
    /// across both while a single move is in progress.
    private func everyFamilyByte() throws -> [String: Data] {
        var family = try installedFamily()
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            return family
        }

        for archiveName in try FileManager.default.contentsOfDirectory(atPath: rootURL.path) {
            let archived = try directorySnapshot(rootURL.appendingPathComponent(archiveName))
            for (name, data) in archived where name.hasPrefix(storeURL.lastPathComponent) {
                XCTAssertNil(family[name], "\(name) exists twice")
                family[name] = data
            }
        }

        return family
    }

    private func directorySnapshot(_ url: URL) throws -> [String: Data] {
        try Dictionary(
            uniqueKeysWithValues: FileManager.default.contentsOfDirectory(atPath: url.path).map { name in
                (name, try Data(contentsOf: url.appendingPathComponent(name)))
            }
        )
    }

    private func snapshot<Names: Sequence>(of names: Names) throws -> [String: Data] where Names.Element == String {
        try Dictionary(
            uniqueKeysWithValues: names.map { name in
                (name, try Data(contentsOf: testDirectory.appendingPathComponent(name)))
            }
        )
    }

    private func resetTestDirectory() throws {
        try FileManager.default.removeItem(at: testDirectory)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
}
