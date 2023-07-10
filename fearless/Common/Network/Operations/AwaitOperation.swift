import Foundation
import RobinHood

final class AwaitOperation<ResultType>: BaseOperation<ResultType> {
    private let lockQueue = DispatchQueue(label: "com.swiftlee.asyncoperation", attributes: .concurrent)

    override var isAsynchronous: Bool {
        true
    }

    private var _isExecuting: Bool = false
    override private(set) var isExecuting: Bool {
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
    override private(set) var isFinished: Bool {
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

    override func start() {
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

    func finish() {
        isExecuting = false
        isFinished = true
    }
}
