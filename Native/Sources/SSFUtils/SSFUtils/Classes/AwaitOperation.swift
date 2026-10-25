import Foundation
import RobinHood

public final class AwaitOperation<ResultType>: BaseOperation<ResultType> {
    private lazy var lockQueue: DispatchQueue = .init(
        label: "co.jp.soramitsu.ssfUtils.awaitOpeation",
        attributes: .concurrent
    )

    override public var isAsynchronous: Bool {
        true
    }

    private var _isExecuting: Bool = false
    override public private(set) var isExecuting: Bool {
        get {
            lockQueue.sync { () -> Bool in
                _isExecuting
            }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lockQueue.sync(flags: [.barrier]) {
                _isExecuting = newValue
            }
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _isFinished: Bool = false
    override public private(set) var isFinished: Bool {
        get {
            lockQueue.sync { () -> Bool in
                _isFinished
            }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lockQueue.sync(flags: [.barrier]) {
                _isFinished = newValue
            }
            didChangeValue(forKey: "isFinished")
        }
    }

    /// Closure to execute to produce operation result.
    public let closure: () async throws -> ResultType

    /**
     *  Create closure operation.
     *
     *  - parameters:
     *    - closure: Closure to execute to produce operation result.
     */

    public init(closure: @escaping () async throws -> ResultType) {
        self.closure = closure
    }

    override public func start() {
        isFinished = false
        isExecuting = true
        main()
    }

    override public func main() {
        super.main()

        if isCancelled {
            finish()
            return
        }

        if result != nil {
            finish()
            return
        }

        Task {
            do {
                let executionResult = try await closure()
                result = .success(executionResult)
                finish()
            } catch {
                result = .failure(error)
                finish()
            }
        }
    }

    private func finish() {
        isExecuting = false
        isFinished = true
    }
}
