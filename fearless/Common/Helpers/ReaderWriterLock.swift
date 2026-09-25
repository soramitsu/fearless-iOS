import Foundation

final class ReaderWriterLock {
    private let queue = DispatchQueue(label: "co.jp.soramitsu.rwLock.\(UUID().uuidString)", attributes: .concurrent)

    // New-feature final-send reads must never wait on a writer that can be
    // waiting on the same socket. Mark queued writers before returning to the
    // caller, so the try-read also rejects changes not yet applied.
    private let admission = NSLock()
    private var pendingWriters = 0

    func tryConcurrentlyRead<T>(_ block: () throws -> T) rethrows -> T? {
        guard admission.try() else { return nil }
        defer { admission.unlock() }
        guard pendingWriters == 0 else { return nil }
        return try block()
    }

    func concurrentlyRead<T>(_ block: () throws -> T) rethrows -> T {
        try queue.sync {
            try block()
        }
    }

    func exclusivelyWrite(_ block: @escaping (() -> Void)) {
        admission.lock()
        pendingWriters += 1
        admission.unlock()
        queue.async(flags: .barrier) {
            block()
            self.admission.lock()
            self.pendingWriters -= 1
            self.admission.unlock()
        }
    }
}
