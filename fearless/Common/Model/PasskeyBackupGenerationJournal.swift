import Darwin
import Foundation

/// App-private, no-backup storage for exact encrypted candidates. No method uploads or promotes a head.
final class PasskeyBackupGenerationJournal {
    enum Boundary { case afterWrite, afterFileSync }

    private static let directoryName = "passkey-generations-v1"
    private static let maximumEntries = 64
    private let directoryURL: URL
    private let directoryFD: Int32
    private let lockFD: Int32
    private static let processLock = NSLock()
    private let fileSync: (Int32) -> Int32
    private let boundaryHook: (Boundary) throws -> Void

    static func applicationSupport() throws -> PasskeyBackupGenerationJournal {
        let parent = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        return try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
    }

    /// The parent must be the app's Application Support directory, or a private test fixture.
    init(
        parentDirectoryURL: URL, parentSync: (Int32) -> Int32 = { Darwin.fsync($0) },
        fileSync: @escaping (Int32) -> Int32 = { Darwin.fsync($0) },
        boundaryHook: @escaping (Boundary) throws -> Void = { _ in }
    ) throws {
        let parentFD = Darwin.open(parentDirectoryURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard parentFD >= 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
        defer { _ = Darwin.close(parentFD) }
        try Self.requireDirectory(parentFD)
        let name = Self.directoryName
        guard Darwin.mkdirat(parentFD, name, mode_t(S_IRWXU)) == 0 || errno == EEXIST else {
            throw PasskeyBackupGenerationJournalError.unavailable
        }
        let openedDirectory = Darwin.openat(parentFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard openedDirectory >= 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
        do {
            try Self.requireDirectory(openedDirectory)
            let url = parentDirectoryURL.appendingPathComponent(name, isDirectory: true)
            var resourceURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try resourceURL.setResourceValues(values)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path
            )
            let openedLock = Darwin.openat(
                openedDirectory, ".lock", O_RDWR | O_CREAT | O_NOFOLLOW, mode_t(S_IRUSR | S_IWUSR)
            )
            guard openedLock >= 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
            do {
                try Self.requirePrivateFile(openedLock, maximum: 0)
                guard Darwin.fsync(openedDirectory) == 0 else {
                    throw PasskeyBackupGenerationJournalError.unavailable
                }
                // The new directory name itself must survive power loss before any POST can be admitted.
                guard parentSync(parentFD) == 0 else {
                    throw PasskeyBackupGenerationJournalError.unavailable
                }
            } catch {
                _ = Darwin.close(openedLock)
                throw error
            }
            directoryURL = url
            directoryFD = openedDirectory
            lockFD = openedLock
            self.fileSync = fileSync
            self.boundaryHook = boundaryHook
        } catch {
            _ = Darwin.close(openedDirectory)
            throw error
        }
    }

    deinit {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        _ = Darwin.close(lockFD)
        _ = Darwin.close(directoryFD)
    }

    /// Call and durably complete this before the first possible Drive create request.
    func persistPrepared(
        operationID: String, candidate: GoogleDrivePasskeyGenerationStorage.Candidate,
        expectedScope: PasskeyBackupGenerationJournalScope
    ) throws -> PasskeyBackupGenerationJournalEntry {
        try PasskeyBackupGenerationJournalRecord.requireOperationID(operationID)
        guard expectedScope.matches(candidate.context) else { throw PasskeyBackupGenerationJournalError.scopeMismatch }
        let entry = PasskeyBackupGenerationJournalEntry(
            operationID: operationID, fileID: candidate.fileID, context: candidate.context,
            bytes: candidate.bytes, sha256: candidate.sha256, createAttempted: false
        )
        let record = try PasskeyBackupGenerationJournalRecord.encode(entry)
        return try locked {
            let name = Self.recordName(operationID)
            if let existing = try readFile(name, maximum: PasskeyBackupGenerationJournalRecord.maximumBytes) {
                guard existing == record else { throw PasskeyBackupGenerationJournalError.invalidRecord }
                try confirmPreparedDurable(name, expected: record)
            } else {
                let entries = try checkedEntries()
                guard entries.count < Self.maximumEntries else {
                    throw PasskeyBackupGenerationJournalError.capacityExceeded
                }
                for prior in entries {
                    if prior.context.storageAccountBinding == entry.context.storageAccountBinding &&
                        prior.fileID == entry.fileID ||
                        prior.context.ownerSubject == entry.context.ownerSubject &&
                        prior.context.backupNamespace == entry.context.backupNamespace &&
                        prior.context.generationId == entry.context.generationId {
                        throw PasskeyBackupGenerationJournalError.invalidRecord
                    }
                }
                try writeExclusive(record, name: name)
            }
            return try verifiedEntry(record, operationID: operationID, expectedScope: expectedScope)
        }
    }

    /// A durable attempt marker allows one create admission. An existing marker means reconcile the same ID.
    func admitFirstCreateAttempt(
        operationID: String, expectedScope: PasskeyBackupGenerationJournalScope
    ) throws -> Bool {
        try PasskeyBackupGenerationJournalRecord.requireOperationID(operationID)
        return try locked {
            guard let record = try readFile(
                Self.recordName(operationID),
                maximum: PasskeyBackupGenerationJournalRecord.maximumBytes
            ) else {
                throw PasskeyBackupGenerationJournalError.invalidRecord
            }
            _ = try verifiedEntry(record, operationID: operationID, expectedScope: expectedScope)
            try confirmPreparedDurable(Self.recordName(operationID), expected: record)
            let marker = PasskeyBackupGenerationJournalRecord.attemptMarker(for: record)
            let name = Self.attemptName(operationID)
            if let existing = try readFile(name, maximum: marker.count) {
                guard existing == marker else { throw PasskeyBackupGenerationJournalError.invalidRecord }
                return false
            }
            try writeExclusive(marker, name: name)
            return true
        }
    }

    func read(
        operationID: String, expectedScope: PasskeyBackupGenerationJournalScope
    ) throws -> PasskeyBackupGenerationJournalEntry? {
        try PasskeyBackupGenerationJournalRecord.requireOperationID(operationID)
        return try locked {
            guard let record = try readFile(
                Self.recordName(operationID),
                maximum: PasskeyBackupGenerationJournalRecord.maximumBytes
            ) else {
                return nil
            }
            return try verifiedEntry(record, operationID: operationID, expectedScope: expectedScope)
        }
    }

    func listPending(
        expectedScope: PasskeyBackupGenerationJournalScope
    ) throws -> [PasskeyBackupGenerationJournalEntry] {
        try locked {
            try checkedEntries().filter { expectedScope.matches($0.context) }
        }
    }

    private func checkedEntries() throws -> [PasskeyBackupGenerationJournalEntry] {
        let names = try fileNames()
        guard names.count <= Self.maximumEntries * 2 + 1 else {
            throw PasskeyBackupGenerationJournalError.capacityExceeded
        }
        let records = names.filter { $0.hasSuffix(".journal") }
        for name in names where name != ".lock" {
            guard name.hasSuffix(".journal") || name.hasSuffix(".attempt") else {
                throw PasskeyBackupGenerationJournalError.invalidRecord
            }
            if name.hasSuffix(".attempt") {
                let id = String(name.dropFirst(3).dropLast(8))
                try PasskeyBackupGenerationJournalRecord.requireOperationID(id)
                guard records.contains(Self.recordName(id)) else {
                    throw PasskeyBackupGenerationJournalError.invalidRecord
                }
            }
        }
        let entries = try records.sorted().map { name in
            let id = String(name.dropFirst(3).dropLast(8))
            try PasskeyBackupGenerationJournalRecord.requireOperationID(id)
            guard let record = try readFile(name, maximum: PasskeyBackupGenerationJournalRecord.maximumBytes) else {
                throw PasskeyBackupGenerationJournalError.invalidRecord
            }
            return try verifiedEntry(record, operationID: id)
        }
        let driveKeys = entries.map { $0.context.storageAccountBinding + "\u{0}" + $0.fileID }
        let generationKeys = entries.map {
            $0.context.ownerSubject + "\u{0}" + $0.context.backupNamespace + "\u{0}" + $0.context.generationId
        }
        guard Set(driveKeys).count == entries.count, Set(generationKeys).count == entries.count else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        return entries
    }

    private func verifiedEntry(
        _ record: Data, operationID: String,
        expectedScope: PasskeyBackupGenerationJournalScope? = nil
    ) throws -> PasskeyBackupGenerationJournalEntry {
        let marker = try readFile(Self.attemptName(operationID), maximum: 40)
        if let marker = marker, marker != PasskeyBackupGenerationJournalRecord.attemptMarker(for: record) {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        let entry = try PasskeyBackupGenerationJournalRecord.decode(record, attempted: marker != nil)
        guard entry.operationID == operationID else { throw PasskeyBackupGenerationJournalError.invalidRecord }
        if let expectedScope = expectedScope, !expectedScope.matches(entry.context) {
            throw PasskeyBackupGenerationJournalError.scopeMismatch
        }
        return entry
    }

    private func locked<Result>(_ action: () throws -> Result) throws -> Result {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        try setFileLock(type: Int16(F_WRLCK), command: F_SETLKW)
        defer { try? setFileLock(type: Int16(F_UNLCK), command: F_SETLK) }
        try Self.requireDirectory(directoryFD)
        try Self.requirePrivateFile(lockFD, maximum: 0)
        try requireDirectoryPathIdentity()
        return try action()
    }

    private func requireDirectoryPathIdentity() throws {
        var pathStatus = stat()
        var descriptorStatus = stat()
        guard Darwin.lstat(directoryURL.path, &pathStatus) == 0,
              Darwin.fstat(directoryFD, &descriptorStatus) == 0,
              (pathStatus.st_mode & S_IFMT) == S_IFDIR,
              pathStatus.st_dev == descriptorStatus.st_dev,
              pathStatus.st_ino == descriptorStatus.st_ino else {
            throw PasskeyBackupGenerationJournalError.unavailable
        }
    }

    private func setFileLock(type: Int16, command: Int32) throws {
        var request = flock()
        request.l_type = type
        request.l_whence = Int16(SEEK_SET)
        while Darwin.fcntl(lockFD, command, &request) != 0 {
            if errno != EINTR { throw PasskeyBackupGenerationJournalError.unavailable }
        }
    }
}

private extension PasskeyBackupGenerationJournal {
    func fileNames() throws -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
        } catch {
            throw PasskeyBackupGenerationJournalError.unavailable
        }
    }

    private func readFile(_ name: String, maximum: Int) throws -> Data? {
        let descriptor = Darwin.openat(directoryFD, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        if descriptor < 0 {
            if errno == ENOENT { return nil }
            throw PasskeyBackupGenerationJournalError.unavailable
        }
        defer { _ = Darwin.close(descriptor) }
        try Self.requirePrivateFile(descriptor, maximum: maximum)
        return try readDescriptor(descriptor, maximum: maximum)
    }

    private func readDescriptor(_ descriptor: Int32, maximum: Int) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
            if count < 0 {
                if errno == EINTR { continue }
                throw PasskeyBackupGenerationJournalError.unavailable
            }
            if count == 0 { break }
            guard result.count + count <= maximum else { throw PasskeyBackupGenerationJournalError.invalidRecord }
            result.append(contentsOf: buffer.prefix(count))
        }
        return result
    }

    private func confirmPreparedDurable(_ name: String, expected: Data) throws {
        let descriptor = Darwin.openat(directoryFD, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
        defer { _ = Darwin.close(descriptor) }
        try Self.requirePrivateFile(descriptor, maximum: expected.count)
        guard try readDescriptor(descriptor, maximum: expected.count) == expected else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        guard fileSync(descriptor) == 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
        try synchronizeDirectory()
    }

    private func writeExclusive(_ data: Data, name: String) throws {
        let descriptor = Darwin.openat(
            directoryFD, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(S_IRUSR | S_IWUSR)
        )
        guard descriptor >= 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
        defer { _ = Darwin.close(descriptor) }
        try Self.requirePrivateFile(descriptor, maximum: data.count)
        try data.withUnsafeBytes { raw in
            var written = 0
            while written < raw.count {
                let count = Darwin.write(descriptor, raw.baseAddress!.advanced(by: written), raw.count - written)
                if count < 0 {
                    if errno == EINTR { continue }
                    throw PasskeyBackupGenerationJournalError.unavailable
                }
                guard count > 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
                written += count
            }
        }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: directoryURL.appendingPathComponent(name).path
        )
        try boundaryHook(.afterWrite)
        guard fileSync(descriptor) == 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
        try boundaryHook(.afterFileSync)
        try synchronizeDirectory()
    }

    private func synchronizeDirectory() throws {
        guard Darwin.fsync(directoryFD) == 0 else { throw PasskeyBackupGenerationJournalError.unavailable }
    }

    private static func requireDirectory(_ descriptor: Int32) throws {
        var status = stat()
        guard Darwin.fstat(descriptor, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFDIR, (status.st_mode & 0o077) == 0,
              status.st_uid == getuid() else { throw PasskeyBackupGenerationJournalError.unavailable }
    }

    private static func requirePrivateFile(_ descriptor: Int32, maximum: Int) throws {
        var status = stat()
        guard Darwin.fstat(descriptor, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFREG, (status.st_mode & 0o077) == 0,
              status.st_uid == getuid(), status.st_nlink == 1,
              status.st_size >= 0, status.st_size <= Int64(maximum) else {
            throw PasskeyBackupGenerationJournalError.unavailable
        }
    }

    private static func recordName(_ operationID: String) -> String { "op-\(operationID).journal" }
    private static func attemptName(_ operationID: String) -> String { "op-\(operationID).attempt" }
}
