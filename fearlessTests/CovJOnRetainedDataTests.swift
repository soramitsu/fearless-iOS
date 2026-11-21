import XCTest
import UIKit
import CoreData
@testable import fearless

final class CovJOnArchiveManagerStub: RetainedDataArchiveManaging {
    var reevaluations: [([RetainedDataArchive]) -> Void] = []
    var restoreRequests: [RetainedDataArchive] = []
    func reevaluate(completion: @escaping ([RetainedDataArchive]) -> Void) { reevaluations.append(completion) }
    func requestRestore(_ archive: RetainedDataArchive, completion _: @escaping (Result<Void, Error>) -> Void) {
        restoreRequests.append(archive)
    }
}

final class CovJOnEncryptorStub: EmergencyWalletMaterialEncrypting {
    private let lock = NSLock()
    private var callCount = 0
    let result: Result<Data, Error>
    init(_ result: Result<Data, Error>) { self.result = result }
    var calls: Int { lock.lock(); defer { lock.unlock() }; return callCount }
    func encrypt(_: EmergencyWalletMaterial, password _: String) throws -> Data {
        lock.lock()
        callCount += 1
        lock.unlock()
        return try result.get()
    }
}

final class CovJOnRetainedListTests: XCTestCase {
    private func archive(_ root: String, restorable: Bool, date: Date) -> RetainedDataArchive {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(root)
            .appendingPathComponent(UUID().uuidString)
        return RetainedDataArchive(url: url, date: date, canRestore: restorable)
    }

    func testListShowsCheckingThenArchivesWithKindDateAndRestorability() throws {
        let manager = CovJOnArchiveManagerStub()
        let controller = RetainedDataRestoreViewController(interactor: manager)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = controller.tableView!
        XCTAssertEqual(controller.title, RecoveryText.string("previous_data"))
        XCTAssertEqual(controller.navigationItem.leftBarButtonItem?.title, RecoveryText.string("close"))
        XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.title, RecoveryText.string("export"))
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 0), RecoveryText.string("checking"))
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let wallet = archive(RetainedStoreSetAside.userRootName, restorable: true, date: date)
        let network = archive(RetainedStoreSetAside.substrateRootName, restorable: false, date: date)
        let completion = try XCTUnwrap(manager.reevaluations.first)
        completion([wallet, network])
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 0), RecoveryText.string("archive_message"))
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)

        let formatted = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        let first = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(first.textLabel?.text, RecoveryText.string("wallet_data") + " · " + formatted)
        XCTAssertEqual(first.detailTextLabel?.text, RecoveryText.string("restore"))
        XCTAssertEqual(first.accessoryType, .disclosureIndicator)
        XCTAssertEqual(first.textLabel?.numberOfLines, 0)
        let second = controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(second.textLabel?.text, RecoveryText.string("network_data") + " · " + formatted)
        XCTAssertEqual(second.detailTextLabel?.text, RecoveryText.string("not_ready"))
        XCTAssertEqual(second.accessoryType, .none)

        completion([])
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 0), RecoveryText.string("no_archives"))
    }

    func testSelectingAnArchiveThatIsNotReadyExplainsWhy() throws {
        let manager = CovJOnArchiveManagerStub()
        let controller = RetainedDataRestoreViewController(interactor: manager)
        let window = try CovJViewFixture.host(controller)
        defer {
            controller.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        manager.reevaluations.first?([archive(RetainedStoreSetAside.substrateRootName, restorable: false, date: Date())])
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(CovJWait.until { controller.presentedViewController is UIAlertController })
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, RecoveryText.string("title"))
        XCTAssertEqual(alert.message, RecoveryText.string("not_ready"))
        XCTAssertEqual(alert.actions.map(\.title), [RecoveryText.string("close")])
        XCTAssertTrue(manager.restoreRequests.isEmpty)
    }

    func testCloseDismissesThePresentedList() throws {
        let host = UIViewController()
        let window = try CovJViewFixture.host(host)
        defer { window.isHidden = true }
        let controller = RetainedDataRestoreViewController(interactor: CovJOnArchiveManagerStub())
        let navigation = UINavigationController(rootViewController: controller)
        host.present(navigation, animated: false)
        XCTAssertTrue(host.presentedViewController === navigation)
        _ = controller.perform(NSSelectorFromString("close"))
        XCTAssertTrue(CovJWait.until { host.presentedViewController == nil })
    }

    func testRouterEntryPointsIgnoreMissingViewsAndAssemblyBuildsTheList() {
        let router = RetainedDataRestoreRouter.shared
        router.showPreviousData(from: nil)
        router.showEmergencyMaterial(from: nil)
        XCTAssertTrue(router === RetainedDataRestoreRouter.shared)
        let view = RetainedDataRestoreAssembly.createView()
        XCTAssertTrue(view is RetainedDataRestoreViewController)
        XCTAssertFalse(view.isViewLoaded, "Building the list must not scan the real archives")
    }
}

final class CovJOnEmergencyExportTests: XCTestCase {
    private let material = EmergencyWalletMaterial(
        records: [.init(tag: "covj-entropy", bytesBase64: "AAE=")],
        unreadableTags: ["covj-seed"]
    )
    private let password = "long enough password"

    private func exportDirectories() -> Int {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)) ?? []
        return items.filter { $0.hasPrefix(SensitiveExportFiles.directoryPrefix) }.count
    }

    private func fill(_ controller: EmergencyWalletMaterialViewController) {
        controller.passwordField.text = password
        controller.confirmationField.text = password
    }

    func testSummaryAndFailedEncryptionKeepTheScreenUsable() throws {
        let encryptor = CovJOnEncryptorStub(.failure(CovJError("seal")))
        let controller = EmergencyWalletMaterialViewController(material: material, encryptor: encryptor)
        controller.loadViewIfNeeded()
        XCTAssertEqual(controller.title, RecoveryText.string("export"))
        let summary = String(format: RecoveryText.string("export_summary"), 1, 1)
        XCTAssertEqual(controller.messageLabel.text, RecoveryText.string("export_warning") + "\n\n" + summary)
        XCTAssertEqual(controller.createButton.title(for: .normal), RecoveryText.string("export_create"))
        XCTAssertEqual(controller.passwordField.placeholder, RecoveryText.string("export_password"))
        XCTAssertEqual(controller.confirmationField.placeholder, RecoveryText.string("export_password_repeat"))

        fill(controller)
        controller.createEncryptedFile()
        XCTAssertFalse(controller.createButton.isEnabled)
        XCTAssertTrue((controller.passwordField.text ?? "").isEmpty)
        XCTAssertTrue((controller.confirmationField.text ?? "").isEmpty)
        controller.createEncryptedFile()
        XCTAssertTrue(CovJWait.until { controller.statusLabel.text == RecoveryText.string("export_failed") })
        XCTAssertEqual(encryptor.calls, 1, "A second tap while sealing is ignored")
        XCTAssertTrue(controller.createButton.isEnabled)
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
    }

    func testSealedFileIsOfferedForSharingAndClosingRemovesIt() throws {
        let baseline = exportDirectories()
        let encryptor = CovJOnEncryptorStub(.success(Data("sealed".utf8)))
        let controller = EmergencyWalletMaterialViewController(material: material, encryptor: encryptor)
        let host = UIViewController()
        let window = try CovJViewFixture.host(host)
        defer {
            host.dismiss(animated: false)
            window.isHidden = true
        }
        let navigation = UINavigationController(rootViewController: controller)
        host.present(navigation, animated: false)
        controller.loadViewIfNeeded()

        fill(controller)
        controller.createEncryptedFile()
        XCTAssertTrue(CovJWait.until(timeout: 5) { controller.statusLabel.text == RecoveryText.string("export_ready") })
        XCTAssertTrue(controller.createButton.isEnabled)
        XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.title, RecoveryText.string("share"))
        XCTAssertEqual(exportDirectories(), baseline + 1)
        CovJWait.until(timeout: 3) { controller.presentedViewController != nil }
        CovJWait.drain(0.5)

        _ = controller.perform(NSSelectorFromString("close"))
        XCTAssertEqual(controller.messageLabel.text, RecoveryText.string("locked"))
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
        XCTAssertFalse(controller.passwordField.isEnabled)
        XCTAssertFalse(controller.createButton.isEnabled)
        XCTAssertEqual(exportDirectories(), baseline)
    }

    func testLockingWhileSealingDiscardsTheFinishedFile() {
        let baseline = exportDirectories()
        let encryptor = CovJOnEncryptorStub(.success(Data("sealed".utf8)))
        let controller = EmergencyWalletMaterialViewController(material: material, encryptor: encryptor)
        controller.loadViewIfNeeded()
        fill(controller)
        controller.createEncryptedFile()
        _ = controller.perform(NSSelectorFromString("redact"))
        XCTAssertTrue(CovJWait.until { encryptor.calls == 1 })
        CovJWait.drain(0.2)
        XCTAssertTrue(CovJWait.until { self.exportDirectories() == baseline })
        XCTAssertNil(controller.statusLabel.text)
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
        XCTAssertEqual(controller.messageLabel.text, RecoveryText.string("locked"))
    }
}

final class CovJOnRetainedStorageTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDown() {
        roots.forEach { try? FileManager.default.removeItem(at: $0) }
        roots = []
        super.tearDown()
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CovJOnRetained-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        roots.append(url)
        return url
    }

    private func createStore(at url: URL, model: NSManagedObjectModel) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        )
        try coordinator.remove(store)
    }

    private func foreignModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "CovJOnForeignThing"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let attribute = NSAttributeDescription()
        attribute.name = "value"
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = true
        entity.properties = [attribute]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    private func cocoaCode(_ block: () throws -> Void) -> CocoaError.Code? {
        do {
            try block()
            return nil
        } catch let error as CocoaError {
            return error.code
        } catch {
            return nil
        }
    }

    func testAsyncReevaluationOfAnEmptyDirectoryFindsNothing() throws {
        let service = RetainedDataRestoreInteractor(directory: try temporaryDirectory())
        var received: [RetainedDataArchive]?
        service.reevaluate { received = $0 }
        XCTAssertTrue(CovJWait.until(timeout: 5) { received != nil })
        XCTAssertEqual(received, [])
    }

    func testRequestsOutsideKnownArchiveRootsAndDamagedRequestsAreRejected() throws {
        let root = try temporaryDirectory()
        let service = RetainedDataRestoreInteractor(directory: root, validate: { _, _ in })
        let stray = RetainedDataArchive(
            url: root.appendingPathComponent("Elsewhere").appendingPathComponent(UUID().uuidString),
            date: Date(),
            canRestore: true
        )
        XCTAssertEqual(cocoaCode { try service.requestRestore(stray) }, .fileReadInvalidFileName)

        let request = root.appendingPathComponent("retained-restore-request.json")
        try Data(repeating: 0x20, count: 5000).write(to: request)
        XCTAssertEqual(cocoaCode { try service.applyPendingRestore() }, .fileReadCorruptFile)

        let missing = #"{"kind":"substrate","archive":"\#(UUID().uuidString)"}"#
        try Data(missing.utf8).write(to: request)
        XCTAssertEqual(cocoaCode { try service.applyPendingRestore() }, .fileNoSuchFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: request.path), "A refused request stays for the next launch")
    }

    func testUserValidatorRejectsAStoreFromAnotherModel() throws {
        let store = try temporaryDirectory().appendingPathComponent("foreign.sqlite")
        try createStore(at: store, model: foreignModel())
        XCTAssertEqual(cocoaCode { try RetainedDataRestoreInteractor.validateStore(store, .user) }, .fileReadCorruptFile)
    }

    func testRestoringWithoutALiveStoreCreatesAnEmptyRollbackGeneration() throws {
        let cases: [(RetainedDataRestoreInteractor.Kind, URL?)] = [
            (.substrate, SubstrateStorageParams.modelVersion.modelURL(in: .main, modelDirectory: SubstrateStorageParams.modelDirectory)),
            (.user, UserStorageParams.modelVersion.modelURL(in: .main, legacyModelDirectory: UserStorageParams.modelDirectory))
        ]
        for (kind, modelURL) in cases {
            let root = try temporaryDirectory()
            let model = try XCTUnwrap(modelURL.flatMap(NSManagedObjectModel.init(contentsOf:)))
            let live = root.appendingPathComponent(kind.fileName)
            try createStore(at: live, model: model)
            let retained = RetainedStoreSetAside(storeURL: live, rootName: kind.rootName, fileManager: .default)
            let chosen = try XCTUnwrap(retained.setAside())
            XCTAssertFalse(FileManager.default.fileExists(atPath: live.path))

            var validations = 0
            let service = RetainedDataRestoreInteractor(directory: root, validate: { _, validated in
                XCTAssertEqual(validated, kind)
                validations += 1
            })
            try service.requestRestore(RetainedDataArchive(url: chosen, date: Date(), canRestore: true))
            try service.applyPendingRestore()

            XCTAssertTrue(FileManager.default.fileExists(atPath: live.path), "\(kind)")
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("retained-restore-request.json").path))
            XCTAssertGreaterThanOrEqual(try retained.retainedArchiveURLs().count, 2, "The empty current generation is kept for rollback")
            XCTAssertTrue(try retained.retainedArchiveURLs().contains(chosen))
            XCTAssertGreaterThanOrEqual(validations, 2)
        }
    }

    func testExportFileHelpersRejectDamagedFilesAndCleanUpFailedWrites() throws {
        XCTAssertThrowsError(try EmergencyWalletMaterialEncryptor.decrypt(Data("{}".utf8), password: "irrelevant")) { error in
            XCTAssertEqual(error as? EmergencyWalletMaterialEncryptionError, .invalidFile)
        }
        let scratch = try temporaryDirectory()
        XCTAssertThrowsError(try SensitiveExportFiles.write(
            Data("secret".utf8),
            fileName: "missing-folder/file.json",
            temporaryDirectory: scratch
        ))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: scratch.path)
        XCTAssertTrue(leftovers.isEmpty, "A failed write must not leave its private directory behind")
    }
}
