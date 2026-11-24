import Foundation

/// What a relay socket reports, in order.
public enum RelayTransportEvent: Sendable {
    case opened
    case text(String)
    case closed(code: Int?, reason: String?)
    case failed(String)
}

/// One WebSocket connection to the relay. Tests stand in an in-memory relay.
public protocol RelayTransport: AnyObject, Sendable {
    /// Events of this connection, in the order they happened. The stream ends after `closed` or `failed`.
    var events: AsyncStream<RelayTransportEvent> { get }
    func connect(request: URLRequest)
    func send(text: String) async throws
    func sendPing() async throws
    func close()
}

public protocol RelayTransportFactory: Sendable {
    func makeTransport() -> RelayTransport
}

public struct URLSessionRelayTransportFactory: RelayTransportFactory {
    public init() {}

    public func makeTransport() -> RelayTransport {
        URLSessionRelayTransport()
    }
}

public enum RelayTransportError: Error, Equatable {
    case notConnected
    case sendFailed(String)
}

/// The relay over `URLSessionWebSocketTask`.
final class URLSessionRelayTransport: NSObject, RelayTransport, URLSessionWebSocketDelegate, @unchecked Sendable {
    let events: AsyncStream<RelayTransportEvent>
    private let continuation: AsyncStream<RelayTransportEvent>.Continuation
    private let lock = NSLock()
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var finished = false

    /// Frames above this size are dropped, not handed on.
    private static let maximumMessageSize = 4 * 1024 * 1024

    override init() {
        var continuation: AsyncStream<RelayTransportEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
        super.init()
    }

    func connect(request: URLRequest) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = Self.maximumMessageSize

        lock.lock()
        self.session = session
        self.task = task
        lock.unlock()

        task.resume()
        receiveNext(on: task)
    }

    private func currentTask() -> URLSessionWebSocketTask? {
        lock.lock()
        defer { lock.unlock() }
        return finished ? nil : task
    }

    private func receiveNext(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .success(.string(text)):
                self.yield(.text(text))
                self.receiveNext(on: task)
            case let .success(.data(data)):
                if let text = String(data: data, encoding: .utf8) {
                    self.yield(.text(text))
                }
                self.receiveNext(on: task)
            case let .failure(error):
                self.finish(.failed(error.localizedDescription))
            @unknown default:
                self.receiveNext(on: task)
            }
        }
    }

    private func yield(_ event: RelayTransportEvent) {
        lock.lock()
        let isFinished = finished
        lock.unlock()
        guard !isFinished else {
            return
        }
        continuation.yield(event)
    }

    private func finish(_ event: RelayTransportEvent) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let session = self.session
        let task = self.task
        self.session = nil
        self.task = nil
        lock.unlock()

        continuation.yield(event)
        continuation.finish()
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }

    func send(text: String) async throws {
        guard let task = currentTask() else {
            throw RelayTransportError.notConnected
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(.string(text)) { error in
                if let error {
                    continuation.resume(throwing: RelayTransportError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func sendPing() async throws {
        guard let task = currentTask() else {
            throw RelayTransportError.notConnected
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: RelayTransportError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func close() {
        finish(.closed(code: 1000, reason: "closed by client"))
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol _: String?) {
        yield(.opened)
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        finish(.closed(code: closeCode.rawValue, reason: reason.flatMap { String(data: $0, encoding: .utf8) }))
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        finish(.failed(error?.localizedDescription ?? "connection ended"))
    }
}
