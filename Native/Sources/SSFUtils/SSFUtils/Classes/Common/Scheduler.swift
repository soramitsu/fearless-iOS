import Foundation

public protocol SchedulerProtocol: AnyObject {
    func notifyAfter(_ seconds: TimeInterval)
    func cancel()
}

public protocol SchedulerDelegate: AnyObject {
    func didTrigger(scheduler: SchedulerProtocol)
}

public final class Scheduler: NSObject, SchedulerProtocol {
    weak var delegate: SchedulerDelegate?

    let callbackQueue: DispatchQueue?

    private var lock = NSLock()
    private var timer: DispatchSourceTimer?

    public init(with delegate: SchedulerDelegate, callbackQueue: DispatchQueue? = nil) {
        self.delegate = delegate
        self.callbackQueue = callbackQueue

        super.init()
    }

    deinit {
        cancel()
    }

    public func notifyAfter(_ seconds: TimeInterval) {
        lock.lock()

        defer {
            lock.unlock()
        }

        clearTimer()

        timer = DispatchSource.makeTimerSource()
        timer?.schedule(
            deadline: .now() + .milliseconds(Int(1000.0 * seconds)),
            repeating: DispatchTimeInterval.never
        )
        timer?.setEventHandler { [weak self] in
            self?.handleTrigger()
        }

        timer?.resume()
    }

    public func cancel() {
        lock.lock()

        defer {
            lock.unlock()
        }

        clearTimer()
    }

    private func clearTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    @objc
    private func handleTrigger() {
        lock.lock()

        defer {
            lock.unlock()
        }

        timer = nil

        if let callbackQueue = callbackQueue {
            callbackQueue.async {
                self.delegate?.didTrigger(scheduler: self)
            }
        } else {
            delegate?.didTrigger(scheduler: self)
        }
    }
}
