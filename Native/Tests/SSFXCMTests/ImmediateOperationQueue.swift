import Foundation
import XCTest

/// Runs an operation to completion before `addOperation` returns, like a request that is already
/// answered by the time it is queued. Code that arranges its completion handling after queueing
/// the operation never sees such an operation finish.
final class ImmediateOperationQueue: OperationQueue, @unchecked Sendable {
    override func addOperation(_ op: Operation) {
        op.start()
    }
}

/// Completes an async call on the side so that a test can give up on it instead of hanging.
final class AsyncResult<Value> {
    private(set) var value: Value?
    let completed: XCTestExpectation

    init(_ completed: XCTestExpectation) {
        self.completed = completed
    }

    func store(_ value: Value) {
        self.value = value
        completed.fulfill()
    }
}
