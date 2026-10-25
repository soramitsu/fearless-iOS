import CoreData
import Darwin
import Foundation

/// Reads and validates retained stores on private copies. No original archive
/// is opened by Core Data, migrated, pruned, or rewritten.
final class RetainedDataRestoreInteractor: RetainedDataArchiveManaging {
    enum Kind: String, CaseIterable {
        case user, substrate

        var fileName: String {
            self == .user ? UserStorageParams.databaseName : SubstrateStorageParams.databaseName
        }

        var rootName: String {
            self == .user ? RetainedStoreSetAside.userRootName : RetainedStoreSetAside.substrateRootName
        }

        var limits: SQLiteStoreFamilyCopyLimits {
            self == .user ? .userStorageProduction : .substrateStorageProduction
        }
    }

    private struct Request: Codable {
        let kind: Kind
        let archive: String
    }

    static let shared = RetainedDataRestoreInteractor(directory: SubstrateStorageParams.storageDirectoryURL)
    private let directory: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.retained-data", qos: .utility)
    private let validate: (URL, Kind) throws -> Void
    private let replacementBoundaryHook: (CrashConsistentStoreReplacementBoundary) throws -> Void
    private var requestURL: URL {
        directory.appendingPathComponent("retained-restore-request.json")
    }

    init(
        directory: URL,
        fileManager: FileManager = .default,
        validate: @escaping (URL, Kind) throws -> Void = validateStore,
        replacementBoundaryHook: @escaping (CrashConsistentStoreReplacementBoundary) throws -> Void = { _ in }
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.validate = validate
        self.replacementBoundaryHook = replacementBoundaryHook
    }

    func reevaluate(completion: @escaping ([RetainedDataArchive]) -> Void) {
        queue.async {
            let archives = self.reevaluateSynchronously()
            DispatchQueue.main.async { completion(archives) }
        }
    }

    /// Deliberately called on every launch, without waiting for or gating a
    /// healthy wallet. No cached validator failure suppresses another attempt.
    func reevaluateSynchronously() -> [RetainedDataArchive] {
        Kind.allCases.flatMap { kind in
            let archives = ((try? setAside(for: kind).retainedArchiveURLs()) ?? [])
                .filter { UUID(uuidString: $0.lastPathComponent) != nil }
            return archives.map { archive in
                let date = (try? archive.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? .distantPast
                let canRestore: Bool
                do {
                    try withPrivateCopy(archive: archive, kind: kind) { copy in try validate(copy, kind) }
                    canRestore = true
                } catch { canRestore = false }
                return RetainedDataArchive(url: archive, date: date, canRestore: canRestore)
            }
        }.sorted { $0.date > $1.date }
    }

    func requestRestore(_ archive: RetainedDataArchive, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            let result = Result { try self.requestRestore(archive) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    func requestRestore(_ archive: RetainedDataArchive) throws {
        guard let kind = kind(for: archive.url),
              try setAside(for: kind).retainedArchiveURLs().contains(archive.url) else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        // Recheck with current validators; a stale UI status cannot authorize an
        // unvalidated replacement. The authentication gate lives in the router.
        try withPrivateCopy(archive: archive.url, kind: kind) { try validate($0, kind) }
        let request = Request(kind: kind, archive: archive.url.lastPathComponent)
        try persist(JSONEncoder().encode(request), at: requestURL)
    }

    /// Called before any Core Data coordinator opens a store. The current live
    /// family is archived first, then the existing replacement journal handles
    /// interruption/rollback. A restore failure leaves normal startup free to
    /// open its current store; both generations remain available for export.
    func applyPendingRestore() throws {
        guard fileManager.fileExists(atPath: requestURL.path) else { return }
        let values = try requestURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) < 4096 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        guard UUID(uuidString: request.archive) != nil else { throw CocoaError(.fileReadCorruptFile) }
        let archive = directory.appendingPathComponent(request.kind.rootName).appendingPathComponent(request.archive)
        guard try setAside(for: request.kind).retainedArchiveURLs().contains(archive) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try withPrivateCopy(archive: archive, kind: request.kind) { copy in
            try validate(copy, request.kind)
            let live = directory.appendingPathComponent(request.kind.fileName)
            let replacer = CrashConsistentStoreReplacer(storeURL: live, fileManager: fileManager, storeReplacer: {
                try NSPersistentStoreCoordinator.replaceStore(at: $0, withStoreAt: $1)
            }, boundaryHook: replacementBoundaryHook)
            try replacer.reconcile { try self.validate($0, request.kind) }
            if try !replacer.liveStoreExistsSafely() {
                // An empty current-generation store supplies the rollback family.
                // It never changes any keychain item or authentication setting.
                try Self.createEmptyStore(at: live, kind: request.kind)
            }
            try preserveLiveFamily(live, kind: request.kind)
            try replacer.replaceStore(with: copy) { try self.validate($0, request.kind) }
        }
        try fileManager.removeItem(at: requestURL)
        try synchronize(directory)
    }

    private func kind(for archive: URL) -> Kind? {
        Kind.allCases
            .first {
                directory.appendingPathComponent($0.rootName).standardizedFileURL == archive.deletingLastPathComponent()
                    .standardizedFileURL
            }
    }

    private func setAside(for kind: Kind) -> RetainedStoreSetAside {
        RetainedStoreSetAside(
            storeURL: directory.appendingPathComponent(kind.fileName),
            rootName: kind.rootName,
            fileManager: fileManager
        )
    }

    private func withPrivateCopy<T>(archive: URL, kind: Kind, body: (URL) throws -> T) throws -> T {
        let root = fileManager.temporaryDirectory.appendingPathComponent("RetainedValidation-" + UUID().uuidString)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: root) }
        let copy = root.appendingPathComponent(kind.fileName)
        try SQLiteStoreFamilyCopier.copy(
            from: archive.appendingPathComponent(kind.fileName),
            to: copy,
            includingSharedMemory: false,
            fileManager: fileManager,
            limits: kind.limits
        )
        return try body(copy)
    }

    private func preserveLiveFamily(_ live: URL, kind: Kind) throws {
        let root = directory.appendingPathComponent(kind.rootName)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true,
              values.isSymbolicLink != true else { throw CocoaError(.fileReadInvalidFileName) }
        let pending = root.appendingPathComponent("pending-" + UUID().uuidString)
        try fileManager.createDirectory(at: pending, withIntermediateDirectories: false)
        // Incomplete preparations stay retained too; they are never substituted
        // for a completed archive and never used to suppress future validation.
        try SQLiteStoreFamilyCopier.copy(
            from: live,
            to: pending.appendingPathComponent(kind.fileName),
            includingSharedMemory: true,
            fileManager: fileManager,
            limits: kind.limits
        )
        for suffix in RetainedStoreSetAside.storeFamilySuffixes {
            let member = pending.appendingPathComponent(kind.fileName + suffix)
            if fileManager.fileExists(atPath: member.path) {
                let handle = try FileHandle(forUpdating: member)
                try handle.synchronize()
                try handle.close()
            }
        }
        try synchronize(pending)
        try fileManager.moveItem(at: pending, to: root.appendingPathComponent(UUID().uuidString))
        try synchronize(root)
    }

    private func persist(_ data: Data, at url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        let handle = try FileHandle(forUpdating: url)
        try handle.synchronize()
        try handle.close()
        try synchronize(directory)
    }

    private func synchronize(_ url: URL) throws {
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else { throw POSIXError(.EIO) }
    }

    static func validateStore(_ url: URL, _ kind: Kind) throws {
        if kind == .substrate {
            // Strict migration never uses the cache-rebuild/set-aside fallback.
            try SubstrateStorageMigrator(
                targetVersion: SubstrateStorageParams.modelVersion,
                storeURL: url,
                modelDirectory: SubstrateStorageParams.modelDirectory,
                fileManager: .default
            ).performMigration()
        } else {
            // Wallet archives must not invoke keychain migrations during a
            // preview. Check their shipped model and open read-only; the normal
            // startup migrator handles the accepted copy after restoration.
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: [NSReadOnlyPersistentStoreOption: true]
            )
            guard let model = UserStorageVersion.allCases.compactMap({ version in
                version.modelURL(in: .main, legacyModelDirectory: UserStorageParams.modelDirectory)
                    .flatMap(NSManagedObjectModel.init(contentsOf:))
            }).first(where: { $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            let store = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: url,
                options: [NSReadOnlyPersistentStoreOption: true]
            )
            try coordinator.remove(store)
        }
    }

    private static func createEmptyStore(at url: URL, kind: Kind) throws {
        let modelURL: URL?
        if kind == .user {
            modelURL = UserStorageParams.modelVersion.modelURL(
                in: .main,
                legacyModelDirectory: UserStorageParams.modelDirectory
            )
        } else {
            modelURL = SubstrateStorageParams.modelVersion.modelURL(
                in: .main,
                modelDirectory: SubstrateStorageParams.modelDirectory
            )
        }
        guard let modelURL,
              let model = NSManagedObjectModel(contentsOf: modelURL) else { throw CocoaError(.fileReadCorruptFile) }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        )
        try coordinator.remove(store)
    }
}

extension RetainedDataRestoreInteractor.Kind: Codable {}

final class RetainedDataStartupRecovery: Migrating {
    func migrate() throws {
        // Finish a user-requested set-aside before the wallet store is opened.
        _ = try RetainedStoreSetAside(
            storeURL: UserStorageParams.storageURL,
            rootName: RetainedStoreSetAside.userRootName,
            fileManager: .default
        ).reconcile()
        do { try RetainedDataRestoreInteractor.shared.applyPendingRestore() }
        catch { Logger.shared.warning("Retained app-data restore is pending; keeping current data") }
        RetainedDataRestoreInteractor.shared.reevaluate { _ in }
    }
}
