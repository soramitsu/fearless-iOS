import Darwin
import Foundation
import WalletCore

/// Serialize mutations through EngineStore in this process and refuse a second process
/// access while the first has the wallet open. flock on the directory needs no lock file.
final class DirectoryLease: @unchecked Sendable {
    private final class Reference {
        weak var value: DirectoryLease?
        init(_ value: DirectoryLease) {
            self.value = value
        }
    }

    private static let registryLock = NSLock()
    private static var entries: [URL: Reference] = [:]
    private let directory: URL
    private let lock = NSLock()
    private var fd: Int32 = -1

    private init(_ directory: URL) {
        self.directory = directory
    }

    static func shared(for directory: URL) -> DirectoryLease {
        registryLock.withLock {
            if let lease = entries[directory]?.value {
                return lease
            }
            entries = entries.filter { $0.value.value != nil }
            let lease = DirectoryLease(directory)
            entries[directory] = Reference(lease)
            return lease
        }
    }

    func acquire() throws {
        try lock.withLock {
            guard fd == -1 else { return }
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            } catch { throw WalletError.storage("Could not create the wallet directory.") }
            let opened = open(directory.path, O_DIRECTORY | O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
            guard opened >= 0 else { throw WalletError.storage("Could not open the wallet directory.") }
            guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
                close(opened)
                throw WalletError.storage("The wallet directory is open in another process.")
            }
            guard fchmod(opened, 0o700) == 0 else {
                close(opened)
                throw WalletError.storage("Could not protect the wallet directory.")
            }
            fd = opened
        }
    }

    func sync() throws {
        guard lock.withLock({ fd >= 0 && fsync(fd) == 0 }) else {
            throw WalletError.storage("Could not synchronize the wallet directory.")
        }
    }

    deinit {
        if fd >= 0 {
            close(fd)
        }
    }
}
