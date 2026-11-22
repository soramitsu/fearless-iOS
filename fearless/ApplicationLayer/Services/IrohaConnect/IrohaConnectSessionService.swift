import Foundation

protocol IrohaConnectSessionServiceDelegate: AnyObject {
    func irohaConnectSession(
        _ session: IrohaConnectSessionService,
        requestsConnection open: IrohaConnectOpenFrame,
        account: IrohaConnectAccountDescriptor
    )
    func irohaConnectSessionDidApprove(_ session: IrohaConnectSessionService)
    func irohaConnectSession(_ session: IrohaConnectSessionService, requestsSignature request: IrohaConnectPendingSignature)
    func irohaConnectSessionDidCompleteSignature(_ session: IrohaConnectSessionService)
    func irohaConnectSession(_ session: IrohaConnectSessionService, didRefuse notice: IrohaConnectNotice)
    func irohaConnectSession(_ session: IrohaConnectSessionService, didCloseWith error: Error?)
}

enum IrohaConnectSessionServiceError: LocalizedError, Equatable {
    case transportUnavailable
    case authenticationFailed
    case connectTimedOut
    case unexpectedMessage
    case closedByApp

    var errorDescription: String? {
        switch self {
        case .transportUnavailable:
            return "The IrohaConnect session ended. Connect again from the app if you still need it."
        case .authenticationFailed:
            return "The IrohaConnect relay refused the session. Create a new connection in the app."
        case .connectTimedOut:
            return "The app didn't open the IrohaConnect session in time. Create a new connection in the app."
        case .unexpectedMessage:
            return "The relay sent a message Fearless doesn't accept, so the session ended."
        case .closedByApp:
            return nil
        }
    }
}

/// A WebSocket that carries only binary Connect frames.
protocol IrohaConnectTransport: AnyObject {
    /// Called with the subprotocol the relay selected.
    var onOpen: ((String?) -> Void)? { get set }
    var onMessage: ((Data) -> Void)? { get set }
    /// Text frames are not part of the protocol; the session ends when one arrives.
    var onTextMessage: (() -> Void)? { get set }
    var onClose: ((Error?) -> Void)? { get set }

    func open()
    func send(_ data: Data, completion: @escaping (Error?) -> Void)
    func close()
}

struct IrohaConnectSessionTimings: Equatable {
    var connectTimeout: TimeInterval = 20
    /// Torii closes idle sockets; a sequenced Connect Ping keeps the session alive.
    var keepAliveInterval: TimeInterval = 20
    var requestTimeToLive: TimeInterval = 120
}

final class IrohaConnectSessionService {
    weak var delegate: IrohaConnectSessionServiceDelegate?

    let handoff: IrohaConnectWalletURI

    private let accountProvider: IrohaConnectAccountProviding
    private let engine: IrohaConnectProtocolEngine
    private let transport: IrohaConnectTransport
    private let timings: IrohaConnectSessionTimings
    private let makeWalletKeyPair: () -> IrohaConnectWalletKeyPair
    private let queue = DispatchQueue(label: "jp.co.soramitsu.fearlesswallet.irohaconnect.session")
    private var connectTimeout: DispatchWorkItem?
    private var keepAlive: DispatchWorkItem?
    private var requestTimeout: DispatchWorkItem?
    private var isStarted = false
    private var isClosed = false

    init(
        handoff: IrohaConnectWalletURI,
        accountProvider: IrohaConnectAccountProviding = KeychainIrohaConnectAccountProvider(),
        transport: IrohaConnectTransport? = nil,
        timings: IrohaConnectSessionTimings = IrohaConnectSessionTimings(),
        makeWalletKeyPair: @escaping () -> IrohaConnectWalletKeyPair = { IrohaConnectWalletKeyPair() },
        makeRequestID: @escaping () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.handoff = handoff
        self.accountProvider = accountProvider
        self.transport = transport ?? URLSessionIrohaConnectTransport(handoff: handoff)
        self.timings = timings
        self.makeWalletKeyPair = makeWalletKeyPair
        engine = IrohaConnectProtocolEngine(link: handoff, makeRequestID: makeRequestID)
    }

    func start() {
        queue.async { [weak self] in
            self?.startOnQueue()
        }
    }

    func approveConnection(for account: IrohaConnectAccountDescriptor) {
        queue.async { [weak self] in
            self?.approveConnectionOnQueue(for: account)
        }
    }

    func rejectConnection() {
        queue.async { [weak self] in
            guard let self, !isClosed else { return }
            do {
                let frame = try engine.rejectSession()
                send(frame) { [weak self] in self?.finish(error: nil) }
            } catch {
                finish(error: nil)
            }
        }
    }

    func approveSignature(requestID: String) {
        queue.async { [weak self] in
            self?.approveSignatureOnQueue(requestID: requestID)
        }
    }

    func rejectSignature(requestID: String) {
        queue.async { [weak self] in
            guard let self, !isClosed else { return }
            do {
                let frame = try engine.rejectRequest(requestID)
                clearRequestTimeout()
                send(frame)
                dispatchDelegate { $0.irohaConnectSessionDidCompleteSignature(self) }
            } catch {
                finish(error: error)
            }
        }
    }

    /// Ends the session from the wallet side: the dApp is told before the socket closes.
    func close() {
        queue.async { [weak self] in
            guard let self, !isClosed else { return }
            if let frame = engine.disconnect() {
                send(frame) { [weak self] in self?.finish(error: nil) }
                queue.asyncAfter(deadline: .now() + 2) { [weak self] in self?.finish(error: nil) }
            } else {
                finish(error: nil)
            }
        }
    }

    // MARK: - Queue work

    private func startOnQueue() {
        guard !isClosed, !isStarted else { return }
        isStarted = true

        transport.onOpen = { [weak self] selectedProtocol in
            self?.queue.async { self?.handleOpen(selectedProtocol) }
        }
        transport.onMessage = { [weak self] data in
            self?.queue.async { self?.handle(data) }
        }
        transport.onTextMessage = { [weak self] in
            self?.queue.async { self?.finish(error: IrohaConnectSessionServiceError.unexpectedMessage) }
        }
        transport.onClose = { [weak self] _ in
            self?.queue.async {
                guard let self, !self.isClosed else { return }
                self.finish(error: IrohaConnectSessionServiceError.transportUnavailable)
            }
        }
        transport.open()

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, !isClosed, engine.phase == .connecting else { return }
            finish(error: IrohaConnectSessionServiceError.connectTimedOut)
        }
        connectTimeout = timeout
        queue.asyncAfter(deadline: .now() + timings.connectTimeout, execute: timeout)
    }

    private func handleOpen(_ selectedProtocol: String?) {
        guard !isClosed else { return }
        // Torii either echoes the token subprotocol or selects none; anything else is another endpoint.
        if let selectedProtocol, !selectedProtocol.isEmpty, selectedProtocol != handoff.webSocketSubprotocol {
            finish(error: IrohaConnectSessionServiceError.authenticationFailed)
        }
    }

    private func handle(_ data: Data) {
        guard !isClosed else { return }
        do {
            let reaction = try engine.receive(data) { try accountProvider.selectedAccount() }
            for frame in reaction.frames {
                send(frame)
            }
            for event in reaction.events {
                handle(event)
            }
        } catch {
            finish(error: error)
        }
    }

    private func handle(_ event: IrohaConnectProtocolEngine.Event) {
        switch event {
        case let .openRequested(open):
            connectTimeout?.cancel()
            connectTimeout = nil
            scheduleKeepAlive()
            guard let account = engine.approvedAccount else {
                finish(error: IrohaConnectAccountProviderError.accountUnavailable)
                return
            }
            dispatchDelegate { $0.irohaConnectSession(self, requestsConnection: open, account: account) }
        case let .signatureRequested(request):
            installRequestTimeout(for: request.requestID)
            dispatchDelegate { $0.irohaConnectSession(self, requestsSignature: request) }
        case let .refused(_, notice):
            dispatchDelegate { $0.irohaConnectSession(self, didRefuse: notice) }
        case .closedByApp:
            finish(error: IrohaConnectSessionServiceError.closedByApp)
        }
    }

    private func approveConnectionOnQueue(for requestedAccount: IrohaConnectAccountDescriptor) {
        guard !isClosed else { return }
        do {
            guard engine.approvedAccount == requestedAccount else {
                throw IrohaConnectAccountProviderError.accountMismatch
            }
            let walletKeyPair = makeWalletKeyPair()
            let preimage = try engine.approvalPreimage(walletKeyPair: walletKeyPair)
            let signature = try accountProvider.sign(preimage, for: requestedAccount)
            let frame = try engine.approveSession(walletKeyPair: walletKeyPair, signature: signature)
            send(frame) { [weak self] in
                guard let self else { return }
                dispatchDelegate { $0.irohaConnectSessionDidApprove(self) }
            }
            scheduleKeepAlive()
        } catch {
            finish(error: error)
        }
    }

    private func approveSignatureOnQueue(requestID: String) {
        guard !isClosed else { return }
        do {
            guard let pending = engine.pending, pending.requestID == requestID else {
                throw IrohaConnectError.invalidFrame("The signature request is no longer available.")
            }
            // A transaction signature covers the marked hash of the payload the person just reviewed, exactly as
            // the wallet's own transfers sign.
            let signature = try accountProvider.sign(pending.payloadHash, for: pending.account)
            let frame = try engine.approveRequest(requestID, signature: signature)
            clearRequestTimeout()
            send(frame) { [weak self] in
                guard let self else { return }
                dispatchDelegate { $0.irohaConnectSessionDidCompleteSignature(self) }
            }
        } catch {
            finish(error: error)
        }
    }

    private func send(_ data: Data, completion: (() -> Void)? = nil) {
        guard !isClosed else { return }
        transport.send(data) { [weak self] error in
            self?.queue.async {
                guard let self else { return }
                if let error {
                    self.finish(error: error)
                } else {
                    completion?()
                }
            }
        }
    }

    private func scheduleKeepAlive() {
        keepAlive?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !isClosed else { return }
            do {
                guard let ping = try engine.keepAlivePing() else { return }
                send(ping)
                scheduleKeepAlive()
            } catch {
                finish(error: error)
            }
        }
        keepAlive = work
        queue.asyncAfter(deadline: .now() + timings.keepAliveInterval, execute: work)
    }

    private func installRequestTimeout(for requestID: String) {
        clearRequestTimeout()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !isClosed, engine.pending?.requestID == requestID else { return }
            do {
                send(try engine.expireRequest(requestID))
                dispatchDelegate { $0.irohaConnectSession(self, didRefuse: .requestExpired) }
            } catch {
                finish(error: error)
            }
        }
        requestTimeout = work
        queue.asyncAfter(deadline: .now() + timings.requestTimeToLive, execute: work)
    }

    private func clearRequestTimeout() {
        requestTimeout?.cancel()
        requestTimeout = nil
    }

    private func dispatchDelegate(_ callback: @escaping (IrohaConnectSessionServiceDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let delegate = self?.delegate else { return }
            callback(delegate)
        }
    }

    private func finish(error: Error?) {
        guard !isClosed else { return }
        isClosed = true
        _ = engine.disconnect()
        connectTimeout?.cancel()
        keepAlive?.cancel()
        requestTimeout?.cancel()
        connectTimeout = nil
        keepAlive = nil
        requestTimeout = nil
        transport.onOpen = nil
        transport.onMessage = nil
        transport.onTextMessage = nil
        transport.onClose = nil
        transport.close()
        let reported = (error as? IrohaConnectSessionServiceError) == .closedByApp ? nil : error
        dispatchDelegate { [weak self] delegate in
            guard let self else { return }
            delegate.irohaConnectSession(self, didCloseWith: reported)
        }
    }
}

/// `URLSessionWebSocketTask` transport for `wss://<torii>/v1/connect/ws?sid=…&role=wallet` with the
/// `iroha-connect.token.v1.*` subprotocol.
final class URLSessionIrohaConnectTransport: NSObject, IrohaConnectTransport, URLSessionWebSocketDelegate {
    var onOpen: ((String?) -> Void)?
    var onMessage: ((Data) -> Void)?
    var onTextMessage: (() -> Void)?
    var onClose: ((Error?) -> Void)?

    /// How long a socket-closed callback waits so frames already received (the app's encrypted Close, a
    /// refusal) are handled before the close is reported.
    static let closeReportDelay: TimeInterval = 0.5

    private let handoff: IrohaConnectWalletURI
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?

    init(handoff: IrohaConnectWalletURI) {
        self.handoff = handoff
    }

    func open() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        let task = session.webSocketTask(with: handoff.webSocketURL, protocols: [handoff.webSocketSubprotocol])
        task.maximumMessageSize = IrohaConnectLimits.frameBytes
        self.session = session
        self.task = task
        task.resume()
        receive()
    }

    func send(_ data: Data, completion: @escaping (Error?) -> Void) {
        guard let task else {
            completion(IrohaConnectSessionServiceError.transportUnavailable)
            return
        }
        task.send(.data(data), completionHandler: completion)
    }

    func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(.data(data)):
                onMessage?(data)
                receive()
            case .success:
                onTextMessage?()
            case let .failure(error):
                onClose?(error)
            }
        }
    }

    func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol selected: String?) {
        onOpen?(selected)
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith _: URLSessionWebSocketTask.CloseCode,
        reason _: Data?
    ) {
        reportCloseAfterDraining(nil)
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        reportCloseAfterDraining(error)
    }

    /// The delegate can learn of the close before the receive loop has delivered the last frames; the receive
    /// loop reports its own failure once they are drained.
    private func reportCloseAfterDraining(_ error: Error?) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Self.closeReportDelay) { [weak self] in
            self?.onClose?(error)
        }
    }
}
