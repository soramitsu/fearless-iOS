import Foundation
import RobinHood

final class ManualOperation<ResultType>: BaseOperation<ResultType> {
    private let lockQueue = DispatchQueue(label: "jp.co.soramitsu.asyncoperation", attributes: .concurrent)

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
    }

    func finish() {
        if isExecuting {
            isExecuting = false
            isFinished = true
        }
    }
}
