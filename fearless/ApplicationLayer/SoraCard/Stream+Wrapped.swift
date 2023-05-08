import Foundation

@propertyWrapper
class Stream<Value> {
    var stream: AsyncStream<Value> {
        let (stream, continuation) = AsyncStream<Value>.streamWithContinuation()
        continuations.append(continuation)
        return stream
    }

    var wrappedValue: Value {
        didSet {
            _ = continuations.map { $0.yield(wrappedValue) }
        }
    }

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    deinit {
        _ = continuations.map { $0.finish() }
    }

    private var continuations: [AsyncStream<Value>.Continuation] = []
}

public extension AsyncStream {
    static func streamWithContinuation() -> (stream: AsyncStream, continuation: AsyncStream.Continuation) {
        var continuation: AsyncStream.Continuation!
        let stream = self.init { innerContinuation in
            continuation = innerContinuation
        }
        return (stream, continuation)
    }
}
