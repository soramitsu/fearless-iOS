import Foundation

final class ReaderWriterLock {
    private let queue = DispatchQueue(label: "co.jp.soramitsu.rwLock.\(UUID().uuidString)", attributes: .concurrent)

    func concurrentlyRead<T>(_ block: () throws -> T) rethrows -> T {
        try queue.sync {
            try block()
        }
    }

    func exclusivelyWrite(_ block: @escaping (() -> Void)) {
        queue.async(flags: .barrier) {
            block()
        }
    }
}
