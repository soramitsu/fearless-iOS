import Darwin
import Foundation

enum RetainedStoreSetAsideBoundary: Equatable {
    case markerPersisted
    case familyMemberMoved(String)
    case markerRemoved
}

enum RetainedStoreSetAsideInterruption: Error {
    /// Test-only fault used to emulate process death without Swift unwinding.
    case simulatedProcessDeath
}

enum RetainedStoreSetAsideError: LocalizedError {
    case unsafeDirectory(URL)
    case markerPersistenceFailed(URL, Error)
    case familyMemberMoveFailed(URL, Error)
    case familyMemberRemainsInstalled(URL)
    case markerRemovalFailed(URL, Error)
    case directorySynchronizationFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .unsafeDirectory:
            return "The retained store archive contains an unsafe directory"
        case let .markerPersistenceFailed(_, error):
            return "Unable to record a store set-aside: \(error.localizedDescription)"
        case let .familyMemberMoveFailed(_, error):
            return "Unable to move a store file into the retained archive: \(error.localizedDescription)"
        case .familyMemberRemainsInstalled:
            return "A store file is still installed after the store was set aside"
        case let .markerRemovalFailed(_, error):
            return "Unable to complete a store set-aside: \(error.localizedDescription)"
        case let .directorySynchronizationFailed(_, error):
            return "Unable to synchronize a retained store directory: \(error.localizedDescription)"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .unsafeDirectory, .familyMemberRemainsInstalled:
            return nil
        case let .markerPersistenceFailed(_, error),
             let .familyMemberMoveFailed(_, error),
             let .markerRemovalFailed(_, error),
             let .directorySynchronizationFailed(_, error):
            return error
        }
    }
}

/// Moves a SQLite store family the app cannot use out of the way without
/// deleting or rewriting a single byte of it, so the app can start from a
/// fresh store while the previous one stays on the device.
///
/// Every installed family member is renamed into its own directory,
/// `<database directory>/<root name>/<UUID>/`. A marker file written first
/// makes the move durable: a relaunch finishes an interrupted move before
/// anything opens the store. Nothing here removes a store file. The only
/// paths ever unlinked are the marker and empty directories, and a rename
/// never replaces an existing file. Archives are not pruned and stay in device
/// backups, like the store they came from.
///
/// There is no archive limit. A rename adds no bytes, a fresh store that
/// replaces an archived one does not need migrating, and refusing a set-aside
/// would leave the app unable to open, which is worse than one more archive.
final class RetainedStoreSetAside { // swiftlint:disable:this type_body_length
    static let userRootName = "UserStoreRetained"
    static let substrateRootName = "SubstrateStoreRetained"
    static let storeFamilySuffixes = ["", "-wal", "-shm", "-journal"]

    private static let markerFileName = "set-aside-transaction"
    private static let markerTemporaryFileName = "set-aside-transaction.pending"
    private static let markerContents = "fearless-retained-store-set-aside-v1\n"

    private enum PathKind {
        case missing
        case regularFile
        case directory
        case other
    }

    let storeURL: URL
    let rootURL: URL

    private let fileManager: FileManager
    private let boundaryHook: (RetainedStoreSetAsideBoundary) throws -> Void

    private var databaseDirectoryURL: URL {
        storeURL.deletingLastPathComponent()
    }

    /// True while a move that became durable has not been completed. A move
    /// only ever starts inside a root directory this class created, so
    /// anything else at the root path holds no transaction.
    var hasPendingTransaction: Bool {
        guard pathKind(at: rootURL) == .directory else {
            return false
        }

        guard let archiveURLs = try? archiveDirectoryURLs() else {
            return true
        }

        return archiveURLs.contains {
            pathKind(at: markerURL(in: $0)) != .missing
        }
    }

    init(
        storeURL: URL,
        rootName: String,
        fileManager: FileManager,
        boundaryHook: @escaping (RetainedStoreSetAsideBoundary) throws -> Void = { _ in }
    ) {
        self.storeURL = storeURL.standardizedFileURL
        self.fileManager = fileManager
        self.boundaryHook = boundaryHook
        rootURL = self.storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(rootName, isDirectory: true)
    }

    /// Moves the installed family into a new archive and returns the archive
    /// directory, or nil when no family member is installed.
    func setAside() throws -> URL? {
        try reconcile()

        guard !installedFamilySuffixes().isEmpty else {
            return nil
        }

        return try moveInstalledFamilyIntoNewArchive()
    }

    /// Finishes a move that a previous launch made durable but could not
    /// complete. Returns the archive that received the family, if any.
    ///
    /// Something other than a directory at the root path cannot hold a move,
    /// so it never stops a launch here; only a new set-aside refuses it.
    @discardableResult
    func reconcile() throws -> URL? {
        guard pathKind(at: rootURL) == .directory else {
            return nil
        }

        var completedArchiveURL: URL?
        for archiveURL in try archiveDirectoryURLs() {
            if pathKind(at: markerURL(in: archiveURL)) != .missing {
                try completeTransaction(at: archiveURL)
                completedArchiveURL = archiveURL
            }

            removeUncommittedPreparation(at: archiveURL)
        }
        removeDirectoryIfEmpty(rootURL)

        guard completedArchiveURL != nil else {
            return nil
        }

        // A member that had already been archived is never replaced. Whatever
        // is installed under the same name afterwards gets its own archive.
        guard installedFamilySuffixes().isEmpty else {
            return try moveInstalledFamilyIntoNewArchive()
        }

        return completedArchiveURL.flatMap {
            pathKind(at: $0) == .directory ? $0 : nil
        }
    }

    /// Completed archives, newest first.
    func retainedArchiveURLs() throws -> [URL] {
        guard pathKind(at: rootURL) == .directory else {
            return []
        }

        return try archiveDirectoryURLs()
            .filter { archiveURL in
                pathKind(at: markerURL(in: archiveURL)) == .missing &&
                    !archivedFamilySuffixes(in: archiveURL).isEmpty
            }
            .map { ($0, modificationTime(of: $0)) }
            .sorted {
                $0.1 != $1.1
                    ? $0.1 > $1.1
                    : $0.0.lastPathComponent > $1.0.lastPathComponent
            }
            .map(\.0)
    }

    private func moveInstalledFamilyIntoNewArchive() throws -> URL {
        let archiveURL = rootURL.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )

        do {
            try createDirectoryIfMissing(rootURL)
            try fileManager.createDirectory(
                at: archiveURL,
                withIntermediateDirectories: false
            )
            try persistMarker(in: archiveURL)
        } catch {
            removeUncommittedPreparation(at: archiveURL)
            removeDirectoryIfEmpty(rootURL)

            if let setAsideError = error as? RetainedStoreSetAsideError {
                throw setAsideError
            }
            throw RetainedStoreSetAsideError.markerPersistenceFailed(
                archiveURL,
                error
            )
        }
        try boundaryHook(.markerPersisted)

        try completeTransaction(at: archiveURL)

        if let installedSuffix = installedFamilySuffixes().first {
            throw RetainedStoreSetAsideError.familyMemberRemainsInstalled(
                familyURL(storeURL, suffix: installedSuffix)
            )
        }

        return archiveURL
    }

    private func completeTransaction(at archiveURL: URL) throws {
        let archivedStoreURL = archiveURL.appendingPathComponent(
            storeURL.lastPathComponent
        )

        for suffix in Self.storeFamilySuffixes {
            let installedURL = familyURL(storeURL, suffix: suffix)
            let archivedURL = familyURL(archivedStoreURL, suffix: suffix)

            guard
                pathKind(at: installedURL) != .missing,
                pathKind(at: archivedURL) == .missing
            else {
                continue
            }

            do {
                try renameWithoutReplacing(installedURL, to: archivedURL)
            } catch {
                throw RetainedStoreSetAsideError.familyMemberMoveFailed(
                    installedURL,
                    error
                )
            }
            try synchronizeDirectory(archiveURL)
            try synchronizeDirectory(databaseDirectoryURL)
            try boundaryHook(.familyMemberMoved(suffix))
        }

        let markerURL = markerURL(in: archiveURL)
        guard Darwin.unlink(markerURL.path) == 0 || errno == ENOENT else {
            throw RetainedStoreSetAsideError.markerRemovalFailed(
                markerURL,
                currentPOSIXError()
            )
        }
        try synchronizeDirectory(archiveURL)
        try boundaryHook(.markerRemoved)
    }

    private func persistMarker(in archiveURL: URL) throws {
        let temporaryURL = markerTemporaryURL(in: archiveURL)

        try Data(Self.markerContents.utf8).write(
            to: temporaryURL,
            options: .withoutOverwriting
        )

        let handle = try FileHandle(forUpdating: temporaryURL)
        defer {
            try? handle.close()
        }
        try handle.synchronize()

        try renameWithoutReplacing(temporaryURL, to: markerURL(in: archiveURL))
        try synchronizeDirectory(archiveURL)
        try synchronizeDirectory(rootURL)
        try synchronizeDirectory(databaseDirectoryURL)
    }

    /// Removes what a set-aside leaves behind when it stops before its marker
    /// is durable: the temporary marker and the still empty directory. A
    /// directory that holds anything else is left exactly as it is.
    private func removeUncommittedPreparation(at archiveURL: URL) {
        guard
            let names = try? fileManager.contentsOfDirectory(
                atPath: archiveURL.path
            ),
            Set(names).isSubset(of: [Self.markerTemporaryFileName])
        else {
            return
        }

        _ = Darwin.unlink(markerTemporaryURL(in: archiveURL).path)
        removeDirectoryIfEmpty(archiveURL)
    }

    /// `rmdir` cannot remove a directory that still has an entry.
    private func removeDirectoryIfEmpty(_ url: URL) {
        _ = Darwin.rmdir(url.path)
    }

    private func createDirectoryIfMissing(_ url: URL) throws {
        switch pathKind(at: url) {
        case .missing:
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: false
            )
        case .directory:
            break
        case .regularFile, .other:
            throw RetainedStoreSetAsideError.unsafeDirectory(url)
        }
    }

    /// A rename within the database directory moves the file itself, never
    /// its contents, and `RENAME_EXCL` refuses an existing destination.
    private func renameWithoutReplacing(
        _ sourceURL: URL,
        to destinationURL: URL
    ) throws {
        guard
            Darwin.renamex_np(
                sourceURL.path,
                destinationURL.path,
                UInt32(RENAME_EXCL)
            ) != 0
        else {
            return
        }

        guard errno == ENOTSUP else {
            throw currentPOSIXError()
        }

        // A file system without exclusive rename: check, then rename.
        guard pathKind(at: destinationURL) == .missing else {
            throw POSIXError(.EEXIST)
        }
        guard Darwin.rename(sourceURL.path, destinationURL.path) == 0 else {
            throw currentPOSIXError()
        }
    }

    private func synchronizeDirectory(_ url: URL) throws {
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw RetainedStoreSetAsideError.directorySynchronizationFailed(
                url,
                currentPOSIXError()
            )
        }
        defer {
            _ = Darwin.close(descriptor)
        }

        guard Darwin.fsync(descriptor) == 0 else {
            throw RetainedStoreSetAsideError.directorySynchronizationFailed(
                url,
                currentPOSIXError()
            )
        }
    }

    private func currentPOSIXError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    private func installedFamilySuffixes() -> [String] {
        Self.storeFamilySuffixes.filter {
            pathKind(at: familyURL(storeURL, suffix: $0)) != .missing
        }
    }

    private func archivedFamilySuffixes(in archiveURL: URL) -> [String] {
        let archivedStoreURL = archiveURL.appendingPathComponent(
            storeURL.lastPathComponent
        )

        return Self.storeFamilySuffixes.filter {
            pathKind(at: familyURL(archivedStoreURL, suffix: $0)) != .missing
        }
    }

    private func archiveDirectoryURLs() throws -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(atPath: rootURL.path)
                .sorted()
                .map { rootURL.appendingPathComponent($0, isDirectory: true) }
                .filter { pathKind(at: $0) == .directory }
        } catch {
            throw RetainedStoreSetAsideError.unsafeDirectory(rootURL)
        }
    }

    private func modificationTime(of url: URL) -> TimeInterval {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            return 0
        }

        return TimeInterval(fileStatus.st_mtimespec.tv_sec) +
            TimeInterval(fileStatus.st_mtimespec.tv_nsec) / 1_000_000_000
    }

    private func familyURL(_ storeURL: URL, suffix: String) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }

    private func markerURL(in archiveURL: URL) -> URL {
        archiveURL.appendingPathComponent(Self.markerFileName)
    }

    private func markerTemporaryURL(in archiveURL: URL) -> URL {
        archiveURL.appendingPathComponent(Self.markerTemporaryFileName)
    }

    /// `lstat` never follows a link, so a symbolic link is reported, and
    /// later renamed, as the link itself.
    private func pathKind(at url: URL) -> PathKind {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            return errno == ENOENT ? .missing : .other
        }

        switch fileStatus.st_mode & S_IFMT {
        case S_IFREG:
            return .regularFile
        case S_IFDIR:
            return .directory
        default:
            return .other
        }
    }
}

// The set-aside transaction and its crash-safety rules remain co-located.
// swiftlint:disable:this file_length
