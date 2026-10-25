import Foundation

/// Application-owned authorization. The handoff must be invoked synchronously
/// inside the application's authorization critical section, at most once.
/// No secret material or authorization tokens belong in this library.
/// This method must not reenter the socket, cancel this operation, or wait for
/// work that depends on the writer. All blocking writer lock waits and frame
/// preparation precede this call. The handoff only submits bytes to the OS.
public protocol WebSocketWriteAuthorizing: AnyObject {
    func authorize(_ handoff: () throws -> Void) throws
}

public enum AuthorizedWriteError: Error {
    case cancelledBeforeHandoff
    case outcomeUnknown
    case connectionChanged
    case unsupportedTransport
    case unsupportedCompression
    case authorizationDidNotHandoff
    case duplicateHandoff
    case handoffBusy
}

public enum AuthorizedWriteDisposition {
    case notHandedOff
    case mayHaveBeenHandedOff
}

/// Cancellation for one immutable queued write. Cancellation before transport
/// handoff prevents the write. Accepted bytes cannot be recalled; cancellation
/// after handoff reports an unknown outcome and must never trigger a retry.
public final class AuthorizedWrite {
    private let lock = NSLock()
    private let callbackQueue: DispatchQueue
    private var completion: ((Result<Void, Error>) -> Void)?
    private var handedOff = false
    private var finished = false

    internal init(callbackQueue: DispatchQueue, completion: @escaping (Result<Void, Error>) -> Void) {
        self.callbackQueue = callbackQueue
        self.completion = completion
    }

    @discardableResult
    public func cancel() -> AuthorizedWriteDisposition {
        lock.lock()
        let disposition: AuthorizedWriteDisposition = handedOff ? .mayHaveBeenHandedOff : .notHandedOff
        let result: Result<Void, Error> = .failure(
            handedOff ? AuthorizedWriteError.outcomeUnknown : AuthorizedWriteError.cancelledBeforeHandoff
        )
        let callback = takeCompletion()
        lock.unlock()
        deliver(callback, result: result)
        return disposition
    }

    /// Called only after all frame preparation on the engine writer queue.
    /// The action must throw only before transport acceptance, never after it.
    internal func perform(authorization: WebSocketWriteAuthorizing, handoff: () throws -> Void) {
        // Do not hold cancellation state while waiting on application
        // authority: disconnect/cancel must still prevent the handoff.
        lock.lock()
        guard !finished else { lock.unlock(); return }
        lock.unlock()
        do {
            try authorization.authorize {
                // A nonblocking commit attempt is essential: never wait for a
                // library lock after the application's final clock sample.
                guard self.lock.try() else { throw AuthorizedWriteError.handoffBusy }
                defer { self.lock.unlock() }
                guard !self.finished else { throw AuthorizedWriteError.cancelledBeforeHandoff }
                guard !self.handedOff else { throw AuthorizedWriteError.duplicateHandoff }
                try handoff()
                self.handedOff = true
            }
            lock.lock()
            let missingHandoff = !handedOff && !finished
            lock.unlock()
            if missingHandoff { throw AuthorizedWriteError.authorizationDidNotHandoff }
        } catch {
            lock.lock()
            let failure = handedOff ? AuthorizedWriteError.outcomeUnknown : error
            let callback = takeCompletion()
            lock.unlock()
            deliver(callback, result: .failure(failure))
        }
    }

    /// Transport callbacks must be dispatched outside the synchronous handoff
    /// before calling this method, including transports that complete inline.
    internal func complete(_ result: Result<Void, Error>) {
        lock.lock()
        let resolved: Result<Void, Error>
        if handedOff, case .failure = result {
            resolved = .failure(AuthorizedWriteError.outcomeUnknown)
        } else {
            resolved = result
        }
        let callback = takeCompletion()
        lock.unlock()
        deliver(callback, result: resolved)
    }

    // Caller holds lock. User callbacks are never invoked while it is held.
    private func takeCompletion() -> ((Result<Void, Error>) -> Void)? {
        guard !finished else { return nil }
        finished = true
        let callback = completion
        completion = nil
        return callback
    }

    private func deliver(_ callback: ((Result<Void, Error>) -> Void)?, result: Result<Void, Error>) {
        guard let callback = callback else { return }
        callbackQueue.async { callback(result) }
    }
}

/// A transport that can bind a queued write to the same connection and perform
/// a synchronous final handoff. Other transports continue serving legacy writes;
/// an authorized write must fail closed if this contract is unavailable.
internal protocol AuthorizedTransport: Transport {
    func captureWriteContext() -> AnyObject?
    /// Acquire transport locks and validate connection first, then call
    /// operation.perform immediately around the synchronous OS handoff.
    func write(data: Data, context: AnyObject, operation: AuthorizedWrite,
               authorization: WebSocketWriteAuthorizing,
               completion: @escaping (Error?) -> Void) throws
}
