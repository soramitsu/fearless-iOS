import CryptoKit
import Darwin
import Foundation

/// App-private, append-only retention of public signed payment bytes. A completed local
/// write is acknowledged only after both the file and its directory have been synchronized.
/// Partial/corrupt histories are retained and block the affected scope; they are never truncated.
final class SolanaPendingBroadcastJournal {
    enum Boundary { case afterWrite, afterFileSync }
    private static let processLock = NSRecursiveLock()
    private static var leases: [DirectoryIdentity: WeakLease] = [:]
    private static let directoryName = "solana-pending-v1"
    private static let maximumBytes = 64 * 1024 * 1024
    private let directoryURL: URL
    private let directoryFD: Int32
    private let lockLease: LockLease
    private let fileSync: (Int32) -> Int32
    private let directorySync: (Int32) -> Int32
    private let writeBytes: (Int32, UnsafeRawPointer?, Int) -> Int
    private let boundaryHook: (Boundary) throws -> Void

    static func applicationSupport() throws -> SolanaPendingBroadcastJournal {
        let parent = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        // A newly created Application Support directory must also have an acknowledged name.
        let ancestor = Darwin.open(parent.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard ancestor >= 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
        defer { _ = Darwin.close(ancestor) }
        guard Darwin.fsync(ancestor) == 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
        return try SolanaPendingBroadcastJournal(parentDirectoryURL: parent)
    }

    init(
        parentDirectoryURL: URL,
        parentSync: (Int32) -> Int32 = { Darwin.fsync($0) },
        fileSync: @escaping (Int32) -> Int32 = { Darwin.fsync($0) },
        directorySync: @escaping (Int32) -> Int32 = { Darwin.fsync($0) },
        writeBytes: @escaping (Int32, UnsafeRawPointer?, Int) -> Int = { Darwin.write($0, $1, $2) },
        boundaryHook: @escaping (Boundary) throws -> Void = { _ in }
    ) throws {
        Self.processLock.lock(); defer { Self.processLock.unlock() }
        let parent = Darwin.open(parentDirectoryURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard parent >= 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
        defer { _ = Darwin.close(parent) }
        try Self.requireDirectory(parent)
        guard Darwin.mkdirat(parent, Self.directoryName, mode_t(S_IRWXU)) == 0 || errno == EEXIST else {
            throw SolanaPendingBroadcastStoreError.notPersisted
        }
        let directory = Darwin.openat(parent, Self.directoryName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard directory >= 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
        do {
            try Self.requireDirectory(directory)
            var url = parentDirectoryURL.appendingPathComponent(Self.directoryName, isDirectory: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            let lease = try Self.lease(for: directory)
            guard directorySync(directory) == 0, parentSync(parent) == 0 else {
                throw SolanaPendingBroadcastStoreError.notPersisted
            }
            directoryURL = url
            directoryFD = directory; lockLease = lease
            self.fileSync = fileSync; self.directorySync = directorySync; self.boundaryHook = boundaryHook
            self.writeBytes = writeBytes
        } catch { _ = Darwin.close(directory); throw error }
    }

    deinit {
        Self.processLock.lock(); defer { Self.processLock.unlock() }
        _ = Darwin.close(directoryFD)
    }

    /// All reads/CAS/migration remain under the same process and file lock. No RPC await is allowed here.
    func withState<T>(for scope: SolanaPendingBroadcastScope, _ action: (State) throws -> T) throws -> T {
        Self.processLock.lock(); defer { Self.processLock.unlock() }
        // A recursive constructor or peer release is safe, but a nested state mutation
        // must not unlock or overwrite the outer operation's state.
        let lease = lockLease
        guard !lease.active else { throw SolanaPendingBroadcastStoreError.notPersisted }
        try lease.setFileLock(type: Int16(F_WRLCK), command: F_SETLKW)
        lease.active = true
        defer {
            try? lease.setFileLock(type: Int16(F_UNLCK), command: F_SETLK)
            lease.active = false
        }
        try requireDirectoryIdentity()
        try lease.requireIdentity(in: directoryFD)
        let scopeBytes = try JSONSerialization.data(withJSONObject: [scope.walletId, scope.chainId])
        let name = Self.digest(scopeBytes) + ".journal"
        let file = Darwin.openat(
            directoryFD,
            name,
            O_RDWR | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK,
            mode_t(S_IRUSR | S_IWUSR)
        )
        guard file >= 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
        defer { _ = Darwin.close(file) }
        try Self.requireFile(file, maximum: Self.maximumBytes)
        let state = try State(file: file, scope: scope, journal: self)
        defer { state.isOpen = false }
        // Reopening a complete-looking write after an uncertain acknowledgement must not
        // bypass the barrier. This also acknowledges the name of a newly created empty file.
        try synchronize(file)
        return try action(state)
    }

    private func requireDirectoryIdentity() throws {
        var path = stat(); var descriptor = stat()
        guard Darwin.lstat(directoryURL.path, &path) == 0, Darwin.fstat(directoryFD, &descriptor) == 0,
              path.st_mode & S_IFMT == S_IFDIR, path.st_dev == descriptor.st_dev,
              path.st_ino == descriptor.st_ino else {
            throw SolanaPendingBroadcastStoreError.notPersisted
        }
        try Self.requireDirectory(directoryFD)
    }

    private func synchronize(_ file: Int32) throws {
        guard fileSync(file) == 0, directorySync(directoryFD) == 0 else {
            throw SolanaPendingBroadcastStoreError.notPersisted
        }
    }

    final class State {
        private let file: Int32
        private let scope: SolanaPendingBroadcastScope
        private unowned let journal: SolanaPendingBroadcastJournal
        private(set) var bytes: Data?
        private(set) var revision = ""
        private(set) var blocked = false
        private var recordDigests = Set<String>()
        private var sequence = 0
        private var byteCount = 0
        fileprivate var isOpen = true

        fileprivate init(
            file: Int32,
            scope: SolanaPendingBroadcastScope,
            journal: SolanaPendingBroadcastJournal
        ) throws {
            self.file = file; self.scope = scope; self.journal = journal
            let data = try readHistory()
            byteCount = data.count
            guard data.isEmpty || data.last == 0x0A else { throw SolanaPendingBroadcastStoreError.unreadableRecord }
            for line in data.split(separator: 0x0A, omittingEmptySubsequences: false).dropLast() {
                try consume(line)
            }
        }

        private func readHistory() throws -> Data {
            guard Darwin.lseek(file, 0, SEEK_SET) == 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 16384)
            while true {
                let count = Darwin.read(file, &buffer, buffer.count)
                if count < 0, errno == EINTR {
                    continue
                }
                guard count >= 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
                if count == 0 {
                    break
                }
                data.append(contentsOf: buffer.prefix(count))
                guard data.count <= SolanaPendingBroadcastJournal.maximumBytes else {
                    throw SolanaPendingBroadcastStoreError.unreadableRecord
                }
            }
            return data
        }

        private func consume(_ line: Data.SubSequence) throws {
            guard line.count > 65, line[line.startIndex + 64] == 0x20 else {
                throw SolanaPendingBroadcastStoreError.unreadableRecord
            }
            let payload = Data(line.dropFirst(65))
            guard let hash = String(bytes: line.prefix(64), encoding: .utf8),
                  hash == SolanaPendingBroadcastJournal.digest(payload) else {
                throw SolanaPendingBroadcastStoreError.unreadableRecord
            }
            let entry = try JSONDecoder().decode(Entry.self, from: payload)
            guard entry.version == 1, entry.walletId == scope.walletId, entry.chainId == scope.chainId,
                  entry.sequence == sequence + 1, entry.previous == revision, !blocked else {
                throw SolanaPendingBroadcastStoreError.unreadableRecord
            }
            if let conflicts = entry.conflicts {
                guard !conflicts.isEmpty, entry.record == nil else {
                    throw SolanaPendingBroadcastStoreError.unreadableRecord
                }
                blocked = true
            } else {
                bytes = entry.record
                if let record = entry.record {
                    recordDigests.insert(SolanaPendingBroadcastJournal.digest(record))
                }
            }
            sequence = entry.sequence; revision = hash
        }

        func containsHistoricalRecord(_ value: Data) -> Bool {
            recordDigests.contains(SolanaPendingBroadcastJournal.digest(value))
        }

        func block(_ conflicts: [Conflict]) throws {
            guard !conflicts.isEmpty else { throw SolanaPendingBroadcastStoreError.notPersisted }
            try write(record: nil, conflicts: conflicts)
        }

        func append(_ value: Data?) throws {
            try write(record: value, conflicts: nil)
        }

        private func write(record value: Data?, conflicts: [Conflict]?) throws {
            guard isOpen, !blocked else { throw SolanaPendingBroadcastStoreError.notPersisted }
            let entry = Entry(
                version: 1,
                walletId: scope.walletId,
                chainId: scope.chainId,
                sequence: sequence + 1,
                previous: revision,
                record: value,
                conflicts: conflicts
            )
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            let payload = try encoder.encode(entry)
            let hash = SolanaPendingBroadcastJournal.digest(payload)
            var frame = Data((hash + " ").utf8); frame.append(payload); frame.append(0x0A)
            guard byteCount + frame.count <= SolanaPendingBroadcastJournal.maximumBytes else {
                throw SolanaPendingBroadcastStoreError.notPersisted
            }
            try frame.withUnsafeBytes { pointer in
                var offset = 0
                while offset < pointer.count {
                    let count = journal.writeBytes(
                        file, pointer.baseAddress!.advanced(by: offset), pointer.count - offset
                    )
                    if count < 0, errno == EINTR {
                        continue
                    }
                    guard count > 0, count <= pointer.count - offset else {
                        throw SolanaPendingBroadcastStoreError.notPersisted
                    }
                    offset += count
                }
            }
            try journal.boundaryHook(.afterWrite)
            guard journal.fileSync(file) == 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
            try journal.boundaryHook(.afterFileSync)
            guard journal.directorySync(journal.directoryFD) == 0 else {
                throw SolanaPendingBroadcastStoreError.notPersisted
            }
            if conflicts != nil {
                blocked = true
            } else {
                bytes = value
                if let value {
                    recordDigests.insert(SolanaPendingBroadcastJournal.digest(value))
                }
            }
            sequence = entry.sequence; revision = hash; byteCount += frame.count
        }
    }

    private struct Entry: Codable {
        let version: Int
        let walletId: String
        let chainId: String
        let sequence: Int
        let previous: String
        let record: Data?
        let conflicts: [Conflict]?
    }
}

private extension SolanaPendingBroadcastJournal {
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func requireDirectory(_ file: Int32) throws {
        var status = stat()
        guard Darwin.fstat(file, &status) == 0, status.st_mode & S_IFMT == S_IFDIR,
              status.st_mode & 0o077 == 0, status.st_uid == getuid() else {
            throw SolanaPendingBroadcastStoreError.notPersisted
        }
    }

    static func requireFile(_ file: Int32, maximum: Int) throws {
        var status = stat()
        guard Darwin.fstat(file, &status) == 0, status.st_mode & S_IFMT == S_IFREG,
              status.st_mode & 0o077 == 0, status.st_uid == getuid(), status.st_nlink == 1,
              status.st_size >= 0, status.st_size <= off_t(maximum) else {
            throw SolanaPendingBroadcastStoreError.unreadableRecord
        }
    }

    /// POSIX record locks are released by closing *any* descriptor for the same file.
    /// Every instance for the actual directory shares one descriptor. An active operation
    /// keeps its lease alive, including during reentrant peer construction or destruction.
    struct DirectoryIdentity: Hashable {
        let device: dev_t
        let inode: ino_t
    }

    final class WeakLease {
        weak var value: LockLease?
        init(_ value: LockLease) {
            self.value = value
        }
    }

    final class LockLease {
        let file: Int32
        var active = false
        init(file: Int32) {
            self.file = file
        }

        deinit {
            SolanaPendingBroadcastJournal.processLock.lock()
            defer { SolanaPendingBroadcastJournal.processLock.unlock() }
            _ = Darwin.close(file)
        }

        func requireIdentity(in directory: Int32) throws {
            var path = stat(); var descriptor = stat()
            guard Darwin.fstatat(directory, ".lock", &path, AT_SYMLINK_NOFOLLOW) == 0,
                  Darwin.fstat(file, &descriptor) == 0, path.st_dev == descriptor.st_dev,
                  path.st_ino == descriptor.st_ino, path.st_mode & S_IFMT == S_IFREG else {
                throw SolanaPendingBroadcastStoreError.notPersisted
            }
            try SolanaPendingBroadcastJournal.requireFile(file, maximum: 0)
        }

        func setFileLock(type: Int16, command: Int32) throws {
            var request = flock()
            request.l_type = type; request.l_whence = Int16(SEEK_SET)
            while Darwin.fcntl(file, command, &request) != 0 {
                if errno != EINTR {
                    throw SolanaPendingBroadcastStoreError.notPersisted
                }
            }
        }
    }

    static func lease(for directory: Int32) throws -> LockLease {
        var status = stat()
        guard Darwin.fstat(directory, &status) == 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
        let identity = DirectoryIdentity(device: status.st_dev, inode: status.st_ino)
        if let existing = leases[identity]?.value {
            try existing.requireIdentity(in: directory)
            return existing
        }
        // Reject hard links before opening: even closing an invalid extra descriptor
        // could release a different directory's active POSIX lock for the same inode.
        var path = stat()
        if Darwin.fstatat(directory, ".lock", &path, AT_SYMLINK_NOFOLLOW) == 0 {
            guard path.st_mode & S_IFMT == S_IFREG, path.st_nlink == 1 else {
                throw SolanaPendingBroadcastStoreError.notPersisted
            }
        } else if errno != ENOENT {
            throw SolanaPendingBroadcastStoreError.notPersisted
        }
        let file = Darwin.openat(directory, ".lock", O_RDWR | O_CREAT | O_NOFOLLOW, mode_t(S_IRUSR | S_IWUSR))
        guard file >= 0 else { throw SolanaPendingBroadcastStoreError.notPersisted }
        let result = LockLease(file: file)
        try result.requireIdentity(in: directory)
        leases[identity] = WeakLease(result)
        return result
    }
}

extension SolanaPendingBroadcastJournal {
    /// Data values are copied byte-for-byte. Other preference types have no exposed raw
    /// byte representation; a binary property list preserves their complete typed value.
    struct Conflict: Codable {
        let key: String
        let encoding: String
        let bytes: Data

        init(key: String, value: Any) throws {
            self.key = key
            if let data = value as? Data {
                encoding = "data"; bytes = data
            } else {
                encoding = "binary-property-list"
                bytes = try PropertyListSerialization.data(
                    fromPropertyList: ["value": value], format: .binary, options: 0
                )
            }
        }
    }
}
