import CoreData
@testable import fearless
import SoraFoundation
import SoraKeystore
import struct SSFUtils.ScryptParameters
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

final class EmergencyWalletMaterialEncryptionTests: XCTestCase {
    private let password = "correct horse battery"
    private let material = EmergencyWalletMaterial(
        records: [
            .init(tag: "0f5e-entropy", bytesBase64: "AAH/"),
            .init(tag: "0f5e0011-substrateSecretKey", bytesBase64: "+/8=")
        ],
        unreadableTags: ["0f5e-seed"]
    )

    /// Produced by `scripts/recovery/decrypt-emergency-material.py` (OpenSSL scrypt and its
    /// own standard-library scrypt agree) for salt 0x01 * 32, nonce 0x02 * 24, N=1024, r=8, p=1.
    /// Equality proves the app's C scrypt + TweetNacl output opens with the open-source tool.
    private let pythonEncoded = "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEABAAAAQAAAAgAAAACAgICAgICAgICAgICAgICAgICAgICAgIEFQ0wibxzc/nnqpl/IbMou4PXE5pqJ9X8/vT7GNjaYJlrHNg51czqf6w9vXSBSVVfTioTGfaxniKttota18U7ZFm5kJjlQgV+0YTkFzXPBgm+Te9qlEP3vVAFIJ1ZI1oMHBxuwGrT+MVzevDBCUtSXR6E5NHEUzqqSuBynzca1lCs6y469JBJja8zBBXNX2iGNef5QU93nSOa/KGwOMqBH8HOWlOSAlvifaMMecFZO+ym30vuczbGPFiyXnRBJDHkfM0NB/vxVC5CTyUV"

    private func fixedEncryptor() -> EmergencyWalletMaterialEncryptor {
        EmergencyWalletMaterialEncryptor(
            makeScryptParameters: {
                try ScryptParameters(salt: Data(repeating: 1, count: 32), scryptN: 1024, scryptP: 1, scryptR: 8)
            },
            makeNonce: { Data(repeating: 2, count: 24) }
        )
    }

    func testFileMatchesTheOpenSourceDecryptorVectorAndRoundTrips() throws {
        let file = try fixedEncryptor().encrypt(material, password: password)
        let envelope = try JSONDecoder().decode(EncryptedEmergencyWalletMaterial.self, from: file)

        XCTAssertEqual(envelope.format, "fearless-emergency-material-encrypted-v1")
        XCTAssertEqual(envelope.encoding, ["scrypt", "xsalsa20-poly1305"])
        XCTAssertEqual(envelope.records, 2)
        XCTAssertEqual(envelope.unreadable, 1)
        XCTAssertEqual(envelope.encoded, pythonEncoded)
        XCTAssertEqual(try EmergencyWalletMaterialEncryptor.decrypt(file, password: password), material)
    }

    func testDefaultParametersAreRandomAndStillOpen() throws {
        let first = try EmergencyWalletMaterialEncryptor().encrypt(material, password: password)
        let second = try EmergencyWalletMaterialEncryptor().encrypt(material, password: password)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try EmergencyWalletMaterialEncryptor.decrypt(first, password: password), material)
        let envelope = try JSONDecoder().decode(EncryptedEmergencyWalletMaterial.self, from: first)
        let encoded = try XCTUnwrap(Data(base64Encoded: envelope.encoded))
        let parameters = try ScryptParameters(data: encoded)
        XCTAssertEqual(parameters.scryptN, 32768)
        XCTAssertEqual(parameters.scryptR, 8)
        XCTAssertEqual(parameters.scryptP, 1)
    }

    func testFileNeverCarriesASecretOrTagInTheClear() throws {
        let file = try fixedEncryptor().encrypt(material, password: password)
        let text = String(decoding: file, as: UTF8.self)

        for leaked in ["0f5e-entropy", "AAH/", "+/8=", "substrateSecretKey", "0f5e-seed"] {
            XCTAssertFalse(text.contains(leaked), leaked)
        }
    }

    func testShortPasswordsAreRefusedAndWrongPasswordsDoNotOpen() throws {
        XCTAssertThrowsError(try fixedEncryptor().encrypt(material, password: "1234567")) { error in
            XCTAssertEqual(error as? EmergencyWalletMaterialEncryptionError, .weakPassword)
        }

        let file = try fixedEncryptor().encrypt(material, password: password)
        XCTAssertThrowsError(try EmergencyWalletMaterialEncryptor.decrypt(file, password: password + "!")) { error in
            XCTAssertEqual(error as? EmergencyWalletMaterialEncryptionError, .wrongPasswordOrDamagedFile)
        }

        var tampered = try JSONSerialization.jsonObject(with: file) as? [String: Any] ?? [:]
        var encoded = try XCTUnwrap(Data(base64Encoded: tampered["encoded"] as? String ?? ""))
        encoded[encoded.count - 1] ^= 0x01
        tampered["encoded"] = encoded.base64EncodedString()
        let tamperedFile = try JSONSerialization.data(withJSONObject: tampered)
        XCTAssertThrowsError(try EmergencyWalletMaterialEncryptor.decrypt(tamperedFile, password: password))
    }

    func testExportFilesLiveInTheirOwnDirectoryAndAreRemovedWithIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = try SensitiveExportFiles.write(Data("sealed".utf8), fileName: "export.json", temporaryDirectory: root)
        XCTAssertTrue(file.deletingLastPathComponent().lastPathComponent.hasPrefix(SensitiveExportFiles.directoryPrefix))
        XCTAssertEqual(try Data(contentsOf: file), Data("sealed".utf8))

        SensitiveExportFiles.remove(file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path))

        let outsider = root.appendingPathComponent("keep.json")
        try Data().write(to: outsider)
        SensitiveExportFiles.remove(outsider)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsider.path), "Only export directories are ever removed")
    }

    func testLaunchCleanupRemovesSecretLeftoversAndNothingElse() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let temporary = root.appendingPathComponent("tmp", isDirectory: true)
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        try manager.createDirectory(at: inbox, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }

        let legacyExport = temporary.appendingPathComponent("fearless-json-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: legacyExport, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: legacyExport.appendingPathComponent("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY.json"))
        let export = temporary.appendingPathComponent(SensitiveExportFiles.directoryPrefix + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: export, withIntermediateDirectories: true)
        let removable = [
            "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY.json",
            "cnTkNjrs9F3YUoQkwgwHRzcFMvFpmMdmxjAFnWnd3jaJwzmKP.json",
            "0x52908400098527886E0F7030069857D2E4169EE7.json"
        ]
        let kept = ["notes.json", "image.png", "0x1234.json", "fearless-other"]
        for name in removable + kept {
            try Data().write(to: temporary.appendingPathComponent(name))
        }
        let now = Date()
        let oldInbox = inbox.appendingPathComponent("old-keystore.json")
        try Data("{}".utf8).write(to: oldInbox)
        try manager.setAttributes([.modificationDate: now.addingTimeInterval(-2 * 60 * 60)], ofItemAtPath: oldInbox.path)
        // An "Open in Fearless" still importing must keep its file.
        let freshInbox = inbox.appendingPathComponent("fresh-keystore.json")
        try Data("{}".utf8).write(to: freshInbox)
        try manager.setAttributes([.modificationDate: now.addingTimeInterval(-60)], ofItemAtPath: freshInbox.path)

        let removed = SensitiveExportFiles.removeLeftovers(
            fileManager: manager,
            temporaryDirectory: temporary,
            inboxDirectory: inbox,
            now: now
        )

        XCTAssertEqual(removed, removable.count + 3)
        let remaining = Set(try manager.contentsOfDirectory(atPath: temporary.path))
        XCTAssertEqual(remaining, Set(kept))
        XCTAssertEqual(try manager.contentsOfDirectory(atPath: inbox.path), ["fresh-keystore.json"])
    }
}

final class WalletSecretEraserTests: XCTestCase {
    func testForgottenWalletLosesExactlyItsOwnSecrets() throws {
        let keystore = InMemoryKeychain()
        let chainAccount = AccountGenerator.generateChainAccount()
        let removed = AccountGenerator.generateMetaAccount(with: [chainAccount])
        let kept = AccountGenerator.generateMetaAccount()
        let replacedChainKey = removed.metaId + Data(repeating: 0xAB, count: 32).toHex() + "-substrateSecretKey"
        let orphan = UUID().uuidString + "-entropy"

        let removedTags = [
            KeystoreTagV2.entropyTagForMetaId(removed.metaId),
            KeystoreTagV2.substrateSecretKeyTagForMetaId(removed.metaId),
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(removed.metaId),
            KeystoreTagV2.universalWalletSecretSourceTagForMetaId(removed.metaId),
            KeystoreTagV2.substrateSecretKeyTagForMetaId(removed.metaId, accountId: chainAccount.accountId),
            KeystoreTagV2.substrateDerivationTagForMetaId(removed.metaId, accountId: chainAccount.accountId),
            replacedChainKey
        ]
        let keptTags = [
            KeystoreTagV2.entropyTagForMetaId(kept.metaId),
            KeystoreTagV2.substrateSecretKeyTagForMetaId(kept.metaId),
            orphan,
            KeystoreTagV2.pincode.rawValue,
            removed.metaId + "-notAWalletSuffix"
        ]
        for tag in removedTags + keptTags {
            try keystore.saveKey(Data(tag.utf8), with: tag)
        }

        let eraser = WalletSecretEraser(keystore: keystore, storedTags: { removedTags + keptTags })
        let erased = eraser.eraseSecrets(of: [removed], remainingMetaIds: [kept.metaId])

        XCTAssertEqual(erased, removedTags.count)
        for tag in removedTags {
            XCTAssertFalse(try keystore.checkKey(for: tag), tag)
        }
        for tag in keptTags {
            XCTAssertTrue(try keystore.checkKey(for: tag), tag)
        }
    }

    func testNothingIsErasedForAWalletThatStillHasARow() throws {
        let keystore = InMemoryKeychain()
        let wallet = AccountGenerator.generateMetaAccount()
        let tag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        try keystore.saveKey(Data([1]), with: tag)

        let erased = WalletSecretEraser(keystore: keystore, storedTags: { [tag] })
            .eraseSecrets(of: [wallet], remainingMetaIds: [wallet.metaId])

        XCTAssertEqual(erased, 0)
        XCTAssertTrue(try keystore.checkKey(for: tag))
    }

    func testTagsAnotherStoredWalletCouldOwnAreKept() throws {
        let keystore = InMemoryKeychain()
        let removed = AccountGenerator.generateMetaAccount()
        // An identifier that extends the removed one: its tags also start with the removed prefix.
        let longerMetaId = removed.metaId + "ab"
        let foreignTag = longerMetaId + "-entropy"
        try keystore.saveKey(Data([2]), with: foreignTag)

        let erased = WalletSecretEraser(keystore: keystore, storedTags: { [foreignTag] })
            .eraseSecrets(of: [removed], remainingMetaIds: [longerMetaId])

        XCTAssertEqual(erased, 0)
        XCTAssertTrue(try keystore.checkKey(for: foreignTag))
    }

    func testEnumerationFailureStillRemovesTheExactTags() throws {
        let keystore = InMemoryKeychain()
        let wallet = AccountGenerator.generateMetaAccount()
        let tag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        try keystore.saveKey(Data([3]), with: tag)

        struct EnumerationFailed: Error {}
        let erased = WalletSecretEraser(keystore: keystore, storedTags: { throw EnumerationFailed() })
            .eraseSecrets(of: [wallet], remainingMetaIds: [])

        XCTAssertEqual(erased, 1)
        XCTAssertFalse(try keystore.checkKey(for: tag))
    }
}

final class WalletRemovalSafetyTests: XCTestCase {
    func testAWalletThatWasNeverBackedUpKeepsItsKeysWhenRemoved() throws {
        let keystore = InMemoryKeychain()
        let backedUp = AccountGenerator.generateMetaAccount()
        let neverBackedUp = AccountGenerator.generateMetaAccount().replacingIsBackuped(false)
        let backedUpTag = KeystoreTagV2.entropyTagForMetaId(backedUp.metaId)
        let unbackedTag = KeystoreTagV2.entropyTagForMetaId(neverBackedUp.metaId)
        try keystore.saveKey(Data([1]), with: backedUpTag)
        try keystore.saveKey(Data([2]), with: unbackedTag)

        let erased = WalletSecretEraser(keystore: keystore, storedTags: { [backedUpTag, unbackedTag] })
            .eraseSecrets(of: [backedUp, neverBackedUp], remainingMetaIds: [])

        XCTAssertEqual(erased, 1)
        XCTAssertFalse(try keystore.checkKey(for: backedUpTag))
        XCTAssertTrue(try keystore.checkKey(for: unbackedTag), "A mistaken removal of an unbacked wallet must stay recoverable")
    }

    private final class Interactor: WalletOptionInteractorInput {
        var deletions = 0
        func setup(with _: WalletOptionInteractorOutput) {}
        func deleteWallet() { deletions += 1 }
    }

    private final class Router: WalletOptionRouterInput {
        var sheets: [SheetAlertPresentableViewModel] = []
        func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
        func showWalletDetails(from _: ControllerBackedProtocol?, for _: MetaAccountModel) {}
        func showExportWallet(from _: ControllerBackedProtocol?, wallet _: ManagedMetaAccountModel) {}
        func showChangeWalletName(from _: ControllerBackedProtocol?, for _: MetaAccountModel) {}
    }

    func testForgettingAWalletNeedsAFreshAuthorization() throws {
        let wallet = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount(), isSelected: false, order: 1)
        let interactor = Interactor()
        let router = Router()
        let authorizer = RecordingSubmissionAuthorizer()
        let presenter = WalletOptionPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            submissionAuthorizer: authorizer
        )

        presenter.deleteWalletDidTap()
        let remove = try XCTUnwrap(router.sheets.last?.actions.last?.handler)
        remove()
        XCTAssertEqual(interactor.deletions, 0, "Confirming the sheet alone must not erase anything")
        authorizer.answer(0, false)
        XCTAssertEqual(interactor.deletions, 0, "A cancelled PIN removes nothing")

        remove()
        authorizer.answer(1, true)
        XCTAssertEqual(interactor.deletions, 1)
    }
}
