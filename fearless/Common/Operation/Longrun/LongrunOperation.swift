import Foundation
import RobinHood

class LongrunOperation<T>: BaseOperation<T> {
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

    let longrun: AnyLongrun<T>

    init(longrun: AnyLongrun<T>) {
        self.longrun = longrun
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
            longrun.start { [weak self] result in
                self?.result = result
                self?.finish()
            }
        }
    }

    func finish() {
        isExecuting = false
        isFinished = true
    }

    override func cancel() {
        super.cancel()

        longrun.cancel()

        finish()
    }
}
