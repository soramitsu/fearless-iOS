import Darwin
import Foundation
import WalletCore

struct EngineFiles: Sendable {
    let directory: URL
    private let lease: DirectoryLease
    private let flush: @Sendable (Int32, Int32) -> Int32
    init(directory: URL, flush: @escaping @Sendable (Int32, Int32) -> Int32 = { fcntl($0, $1) }) {
        self.directory = URL(fileURLWithPath: directory.path, isDirectory: true).standardized
        lease = DirectoryLease.shared(for: self.directory)
        self.flush = flush
    }

    func access() throws {
        try lease.acquire()
    }

    func removeInterruptedWrites() throws {
        try access()
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path)
            where name.hasPrefix(".fearless-write-") && name.dropFirst(".fearless-write-".count).count == 6 {
            try remove(name)
        }
    }

    func read<T: Decodable>(_ type: T.Type, _ name: String) throws -> T? {
        guard let data = try contents(of: name) else { return nil }
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw WalletError.storage("Unable to read \(name).") }
    }

    func contents(of name: String) throws -> Data? {
        try access()
        do {
            return try Data(contentsOf: directory.appendingPathComponent(name))
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return nil
        } catch { throw WalletError.storage("Unable to read \(name).") }
    }

    func write<T: Encodable>(_ value: T, _ name: String) throws {
        let data: Data
        do { data = try JSONEncoder().encode(value) }
        catch { throw WalletError.storage("Unable to encode \(name).") }
        try write(data, to: name)
    }

    func write(_ data: Data, to name: String) throws {
        try access()
        do {
            var path = Array(directory.appendingPathComponent(".fearless-write-XXXXXX").path.utf8CString)
            let fd = mkstemp(&path)
            guard fd >= 0 else { throw WalletError.storage("Cannot create a private file.") }
            defer { unlink(path) }
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            try handle.write(contentsOf: data)
            guard flush(fd, F_FULLFSYNC) == 0 else {
                throw WalletError.storage("Cannot flush the wallet file to disk.")
            }
            try handle.close()
            guard rename(path, directory.appendingPathComponent(name).path) == 0 else {
                throw WalletError.storage("Cannot replace \(name).")
            }
            try lease.sync()
        } catch { throw WalletError.storage("Unable to write \(name).") }
    }

    func remove(_ name: String) throws {
        try access()
        guard unlink(directory.appendingPathComponent(name).path) == 0 else {
            if errno == ENOENT {
                return
            }
            throw WalletError.storage("Unable to remove \(name).")
        }
        try lease.sync()
    }
}
