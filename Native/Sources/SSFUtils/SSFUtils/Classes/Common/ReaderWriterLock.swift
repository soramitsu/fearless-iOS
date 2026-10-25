import Foundation

public final class ReaderWriterLock {
    private let queue = DispatchQueue(label: "co.jp.soramitsu.rwLock", attributes: .concurrent)

    public init() {}

    public func concurrentlyRead<T>(_ block: () throws -> T) rethrows -> T {
        try queue.sync {
            try block()
        }
    }

    public func exclusivelyWrite(_ block: @escaping (() -> Void)) {
        queue.async(flags: .barrier) {
            block()
        }
    }
}
