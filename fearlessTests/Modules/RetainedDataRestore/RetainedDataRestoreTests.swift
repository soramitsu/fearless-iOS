import CoreData
@testable import fearless
import SoraKeystore
import XCTest

final class RetainedDataRestoreTests: XCTestCase {
    func testShippedKeychainApplicationTagsCanBeInventoriedWithoutWalletRows() throws {
        let keystore = Keychain()
        let tag = "public-ik4-test-" + UUID().uuidString + "-entropy"
        let bytes = Data([0, 255, 1, 128])
        try keystore.saveKey(bytes, with: tag)
        defer { try? keystore.deleteKeyIfExists(for: tag) }
        let tags = try EmergencyWalletMaterialReader.walletTags()
        XCTAssertTrue(tags.contains(tag))
        let material = try EmergencyWalletMaterialReader(keystore: keystore, tags: { tags.filter { $0 == tag } }).read()
        XCTAssertEqual(material.records.count, 1)
        XCTAssertEqual(try Data(base64Encoded: XCTUnwrap(material.records.first).bytesBase64), bytes)
        XCTAssertEqual(try keystore.fetchKey(for: tag), bytes)
    }

    func testEmergencyExportPreservesShippedV1V2TagsAndMalformedBytesExactly() throws {
        let keystore = InMemoryKeychain()
        // Literal tag formats written by shipped pre-multiasset and ecosystem
        // releases. They intentionally do not use the new reader to generate tags.
        let original: [String: Data] = [
            "legacy-address-secretKey": Data([0, 255, 128, 13, 10]),
            "legacy-address-entropy": Data(repeating: 7, count: 16),
            "legacy-address-deriv": Data("//soft/path///password".utf8),
            "legacy-address-seed": Data([1, 2, 3]),
            "old-meta-substrateSecretKey": Data([9, 8, 7]),
            "old-meta-substrateSeed": Data([0, 0, 255]),
            "old-meta-ethereumSecretKey": Data([127]),
            "old-meta-ethereumSeed": Data([128]),
            "old-meta-substrateDeriv": Data("//Alice".utf8),
            "old-meta-ethereumDeriv": Data("m/44'/60'/0'/0/0".utf8),
            "old-meta-tonSecretKey": Data(" AbC  native TON phrase\n".utf8),
            "old-meta-universalWalletSecretSource": Data([0, 255]),
            "old-meta010203-entropy": Data([0, 1, 2, 3])
        ]
        for (tag, bytes) in original {
            try keystore.saveKey(bytes, with: tag)
        }
        try keystore.saveKey(Data("123456".utf8), with: "pincode")
        try keystore.saveKey(Data("provider-private-value".utf8), with: "provider-api-key")
        let reader = EmergencyWalletMaterialReader(
            keystore: keystore,
            tags: { Array(original.keys) + ["pincode", "provider-api-key", "-entropy", "missing-entropy"] }
        )
        let material = try reader.read()
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: material.records.map { ($0.tag, Data(base64Encoded: $0.bytesBase64)) }),
            original.mapValues(Optional.some)
        )
        XCTAssertEqual(material.unreadableTags, ["missing-entropy"])
        for (tag, bytes) in original {
            XCTAssertEqual(try keystore.fetchKey(for: tag), bytes)
        }
        XCTAssertEqual(try keystore.fetchKey(for: "pincode"), Data("123456".utf8))
    }

    func testNothingIsEnumeratedOrReadUntilExistingAuthenticationSucceeds() {
        let reader = RecordingEmergencyReader()
        let access = EmergencyWalletMaterialAccess(reader: reader)
        var authenticate: ((Bool) -> Void)?
        var delivered = false
        access.read(authorize: { authenticate = $0 }, completion: { _ in delivered = true })
        XCTAssertEqual(reader.readCount, 0)
        XCTAssertFalse(delivered)
        authenticate?(false)
        XCTAssertEqual(reader.readCount, 0)
        XCTAssertTrue(delivered)
        authenticate?(true)
        XCTAssertEqual(reader.readCount, 0, "A late success after cancellation cannot export material")
        access.read(authorize: { $0(true) }, completion: { XCTAssertNotNil($0) })
        XCTAssertEqual(reader.readCount, 1)
    }

    func testEverySupportedHistoricalUserArchiveIsReevaluatedWithoutChangingItsBytes() throws {
        let entries = try UpgradeFixtureLoader.historicalStoreModels()
            .filter { $0.store == .user && $0.excluded == nil }
        XCTAssertFalse(entries.isEmpty)
        for entry in entries {
            let root = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let live = root.appendingPathComponent(UserStorageParams.databaseName)
            try createStore(at: live, model: UpgradeFixtureLoader.fixtureModel(for: entry))
            let retained = RetainedStoreSetAside(
                storeURL: live,
                rootName: RetainedStoreSetAside.userRootName,
                fileManager: .default
            )
            let archive = try XCTUnwrap(retained.setAside())
            let original = try snapshot(archive)
            let service = RetainedDataRestoreInteractor(directory: root)
            let first = service.reevaluateSynchronously()
            let second = service.reevaluateSynchronously()
            XCTAssertEqual(first, second)
            XCTAssertEqual(first.count, 1, entry.digest)
            XCTAssertTrue(first[0].canRestore, entry.digest)
            XCTAssertEqual(try snapshot(archive), original, entry.digest)
        }
    }

    func testEveryHistoricalSubstrateArchiveUsesCurrentValidatorsAndLeavesOriginalUntouched() throws {
        let entries = try UpgradeFixtureLoader.historicalStoreModels().filter { $0.store == .substrate }
        XCTAssertGreaterThan(entries.count, 50)
        for entry in entries {
            let root = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let live = root.appendingPathComponent(SubstrateStorageParams.databaseName)
            try createStore(at: live, model: UpgradeFixtureLoader.fixtureModel(for: entry))
            let retained = RetainedStoreSetAside(
                storeURL: live,
                rootName: RetainedStoreSetAside.substrateRootName,
                fileManager: .default
            )
            let archive = try XCTUnwrap(retained.setAside())
            let original = try snapshot(archive)
            let result = RetainedDataRestoreInteractor(directory: root).reevaluateSynchronously()
            XCTAssertEqual(result.count, 1, entry.digest)
            XCTAssertEqual(result[0].canRestore, entry.excluded == nil, entry.digest)
            XCTAssertEqual(try snapshot(archive), original, entry.digest)
        }
    }

    func testRejectedArchiveIsCheckedAgainByNewValidatorAndCannotReplaceHealthyStore() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let live = root.appendingPathComponent(SubstrateStorageParams.databaseName)
        try Data("historically retained unknown model".utf8).write(to: live)
        let retained = RetainedStoreSetAside(
            storeURL: live,
            rootName: RetainedStoreSetAside.substrateRootName,
            fileManager: .default
        )
        let archive = try XCTUnwrap(retained.setAside())
        let original = try snapshot(archive)
        let healthy = Data("current healthy store remains unchanged".utf8)
        try healthy.write(to: live)
        var checks = 0
        let rejected = RetainedDataRestoreInteractor(
            directory: root,
            validate: { _, _ in checks += 1; throw CocoaError(.fileReadCorruptFile) }
        )
        XCTAssertFalse(rejected.reevaluateSynchronously()[0].canRestore)
        XCTAssertFalse(rejected.reevaluateSynchronously()[0].canRestore)
        XCTAssertEqual(checks, 2)
        XCTAssertThrowsError(try rejected.requestRestore(.init(url: archive, date: .distantPast, canRestore: true)))
        XCTAssertEqual(try Data(contentsOf: live), healthy)
        let accepted = RetainedDataRestoreInteractor(directory: root, validate: { _, _ in checks += 1 })
        XCTAssertTrue(accepted.reevaluateSynchronously()[0].canRestore)
        XCTAssertEqual(try snapshot(archive), original)
    }

    func testRestoreKeepsCurrentAndChosenHistoricalWalletStoresAndNeverReadsKeys() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let entry = try XCTUnwrap(UpgradeFixtureLoader.historicalStoreModels()
            .first { $0.store == .user && $0.matchesBundled == "MultiassetUserDataModel_v11" })
        let live = root.appendingPathComponent(UserStorageParams.databaseName)
        try createStore(at: live, model: UpgradeFixtureLoader.fixtureModel(for: entry), walletID: "archived-wallet")
        let retained = RetainedStoreSetAside(
            storeURL: live,
            rootName: RetainedStoreSetAside.userRootName,
            fileManager: .default
        )
        let chosen = try XCTUnwrap(retained.setAside())
        let chosenBytes = try snapshot(chosen)
        let currentURL = try XCTUnwrap(UserStorageParams.modelVersion.modelURL(
            in: .main,
            legacyModelDirectory: UserStorageParams.modelDirectory
        ))
        try createStore(
            at: live,
            model: XCTUnwrap(NSManagedObjectModel(contentsOf: currentURL)),
            walletID: "current-wallet"
        )
        let currentBytes = try Data(contentsOf: live)
        let service = RetainedDataRestoreInteractor(directory: root)
        try service.requestRestore(.init(url: chosen, date: .distantPast, canRestore: true))
        XCTAssertEqual(try Data(contentsOf: live), currentBytes, "A request must not swap a live coordinator's store")
        try service.applyPendingRestore()
        XCTAssertEqual(try snapshot(chosen), chosenBytes)
        let archives = try retained.retainedArchiveURLs()
        XCTAssertEqual(archives.count, 2)
        let preservedCurrent = try XCTUnwrap(archives.first { $0 != chosen })
        XCTAssertEqual(
            try Data(contentsOf: preservedCurrent.appendingPathComponent(live.lastPathComponent)),
            currentBytes
        )
        try RetainedDataRestoreInteractor.validateStore(live, .user)
        try assertWalletIdentity(
            at: live,
            model: UpgradeFixtureLoader.fixtureModel(for: entry),
            expectedID: "archived-wallet"
        )
        try assertWalletIdentity(
            at: preservedCurrent.appendingPathComponent(live.lastPathComponent),
            model: XCTUnwrap(NSManagedObjectModel(contentsOf: currentURL)),
            expectedID: "current-wallet"
        )
        XCTAssertFalse(FileManager.default
            .fileExists(atPath: root.appendingPathComponent("retained-restore-request.json").path))
    }

    func testInterruptedRestoreConvergesAtEachDurableBoundaryWithOriginalArchivesIntact() throws {
        let boundaries: [CrashConsistentStoreReplacementBoundary] = [
            .preparingMarkerPersisted,
            .backupFileCopied(""),
            .committingMarkerPersisted,
            .replacementReturned,
            .destinationValidated,
            .destinationFamilySynced,
            .committedMarkerPersisted,
            .transactionCleaned
        ]
        let entry = try XCTUnwrap(UpgradeFixtureLoader.historicalStoreModels()
            .first { $0.store == .user && $0.excluded == nil })
        let currentURL = try XCTUnwrap(UserStorageParams.modelVersion.modelURL(
            in: .main,
            legacyModelDirectory: UserStorageParams.modelDirectory
        ))
        for boundary in boundaries {
            let root = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let live = root.appendingPathComponent(UserStorageParams.databaseName)
            try createStore(at: live, model: UpgradeFixtureLoader.fixtureModel(for: entry))
            let retained = RetainedStoreSetAside(
                storeURL: live,
                rootName: RetainedStoreSetAside.userRootName,
                fileManager: .default
            )
            let chosen = try XCTUnwrap(retained.setAside())
            let chosenBytes = try snapshot(chosen)
            try createStore(at: live, model: XCTUnwrap(NSManagedObjectModel(contentsOf: currentURL)))
            let originalCurrent = try Data(contentsOf: live)
            let service = RetainedDataRestoreInteractor(directory: root, replacementBoundaryHook: { observed in
                if observed == boundary {
                    throw CrashConsistentStoreReplacementInterruption.simulatedProcessDeath
                }
            })
            try service.requestRestore(.init(url: chosen, date: .distantPast, canRestore: true))
            XCTAssertThrowsError(try service.applyPendingRestore(), "\(boundary)")
            let restarted = RetainedDataRestoreInteractor(directory: root)
            try restarted.applyPendingRestore()
            XCTAssertEqual(try snapshot(chosen), chosenBytes, "\(boundary)")
            XCTAssertTrue(try retained.retainedArchiveURLs().contains { archive in
                (try? Data(contentsOf: archive.appendingPathComponent(live.lastPathComponent))) == originalCurrent
            }, "\(boundary)")
            try RetainedDataRestoreInteractor.validateStore(live, .user)
        }
    }

    func testRestoreRequestValidationRunsOffMainAndCompletesOnMainWithoutChangingLiveStore() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let live = root.appendingPathComponent(SubstrateStorageParams.databaseName)
        try Data("retained fixture".utf8).write(to: live)
        let retained = RetainedStoreSetAside(
            storeURL: live,
            rootName: RetainedStoreSetAside.substrateRootName,
            fileManager: .default
        )
        let archive = try XCTUnwrap(retained.setAside())
        let healthy = Data("healthy live data".utf8)
        try healthy.write(to: live)
        let validated = expectation(description: "background validation")
        let completed = expectation(description: "main completion")
        let service = RetainedDataRestoreInteractor(directory: root, validate: { _, _ in
            XCTAssertFalse(Thread.isMainThread)
            validated.fulfill()
        })
        service.requestRestore(.init(url: archive, date: .distantPast, canRestore: true)) { result in
            XCTAssertTrue(Thread.isMainThread)
            if case let .failure(error) = result {
                XCTFail("Unexpected error: \(error)")
            }
            completed.fulfill()
        }
        wait(for: [validated, completed], timeout: 10)
        XCTAssertEqual(try Data(contentsOf: live), healthy)
    }

    func testRestoreRefusesToCreateAnEmptyStoreOverAnOrphanedLiveWAL() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let entry = try XCTUnwrap(UpgradeFixtureLoader.historicalStoreModels()
            .first { $0.store == .user && $0.excluded == nil })
        let live = root.appendingPathComponent(UserStorageParams.databaseName)
        try createStore(at: live, model: UpgradeFixtureLoader.fixtureModel(for: entry))
        let retained = RetainedStoreSetAside(
            storeURL: live, rootName: RetainedStoreSetAside.userRootName, fileManager: .default
        )
        let chosen = try XCTUnwrap(retained.setAside())
        let original = try snapshot(chosen)
        let orphan = URL(fileURLWithPath: live.path + "-wal")
        let bytes = Data("orphaned previous wallet bytes".utf8)
        try bytes.write(to: orphan)
        let service = RetainedDataRestoreInteractor(directory: root)
        try service.requestRestore(.init(url: chosen, date: .distantPast, canRestore: true))
        XCTAssertThrowsError(try service.applyPendingRestore())
        XCTAssertFalse(FileManager.default.fileExists(atPath: live.path))
        XCTAssertEqual(try Data(contentsOf: orphan), bytes)
        XCTAssertEqual(try snapshot(chosen), original)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetainedDataTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    private func snapshot(_ root: URL) throws -> [String: Data] {
        try Dictionary(uniqueKeysWithValues: FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ).map { try ($0.lastPathComponent, Data(contentsOf: $0)) })
    }

    private func assertWalletIdentity(at url: URL, model: NSManagedObjectModel, expectedID: String) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount"))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.value(forKey: "metaId") as? String, expectedID)
        XCTAssertEqual(rows.first?.value(forKey: "substrateAccountId") as? String, String(repeating: "11", count: 32))
        XCTAssertEqual(rows.first?.value(forKey: "substratePublicKey") as? Data, Data(repeating: 0x11, count: 32))
        context.reset()
    }

    private func createStore(at url: URL, model: NSManagedObjectModel, walletID: String? = nil) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        )
        if let walletID {
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            let row = NSEntityDescription.insertNewObject(forEntityName: "CDMetaAccount", into: context)
            let values: [String: Any] = [
                "metaId": walletID,
                "name": walletID,
                "substrateAccountId": String(repeating: "11", count: 32),
                "substratePublicKey": Data(repeating: 0x11, count: 32),
                "substrateCryptoType": 1,
                "isSelected": true,
                "order": 0,
                "favouriteChainIds": NSArray()
            ]
            for (key, value) in values {
                row.setValue(value, forKey: key)
            }
            try context.save()
            context.reset()
        }
        try coordinator.remove(store)
    }
}

private final class RecordingEmergencyReader: EmergencyWalletMaterialReading {
    var readCount = 0
    func read() throws -> EmergencyWalletMaterial {
        readCount += 1
        return EmergencyWalletMaterial(records: [], unreadableTags: [])
    }
}

final class EmergencyWalletMaterialShareTests: XCTestCase {
    func testShareSheet_keepsPlainTextSecretsOffThePasteboardAndPostingTargets() {
        let excluded = Set(EmergencyWalletMaterialViewController.excludedShareActivities)

        XCTAssertTrue(excluded.contains(.copyToPasteboard))
        XCTAssertTrue(excluded.contains(.print))
        XCTAssertTrue(excluded.contains(.postToTwitter))
        XCTAssertTrue(excluded.contains(.postToFacebook))
        // The user must still be able to take the material to a recovery tool.
        XCTAssertFalse(excluded.contains(.airDrop))
        XCTAssertFalse(excluded.contains(.mail))
    }
}
