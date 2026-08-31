import Foundation

protocol IrohaConnectSessionServiceDelegate: AnyObject {
    func irohaConnectSession(
        _ session: IrohaConnectSessionService,
        requestsConnection open: IrohaConnectOpenFrame,
        account: IrohaConnectAccountDescriptor
    )
    func irohaConnectSessionDidApprove(_ session: IrohaConnectSessionService)
    func irohaConnectSession(
        _ session: IrohaConnectSessionService,
        requestsSignature request: IrohaConnectSignRawRequest,
        account: IrohaConnectAccountDescriptor
    )
    func irohaConnectSessionDidCompleteSignature(_ session: IrohaConnectSessionService)
    func irohaConnectSession(_ session: IrohaConnectSessionService, didCloseWith error: Error?)
}

enum IrohaConnectSessionServiceError: LocalizedError {
    case transportUnavailable
    case authenticationFailed
    case connectTimedOut
    case requestTimedOut
    case unexpectedMessage
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .transportUnavailable:
            return "Fearless could not open the authenticated IrohaConnect channel."
        case .authenticationFailed:
            return "The IrohaConnect relay did not confirm the expected session authentication."
        case .connectTimedOut:
            return "The IrohaConnect pairing request timed out. Create a new request in the dApp."
        case .requestTimedOut:
            return "The contract signature request expired before it was approved."
        case .unexpectedMessage:
            return "The dApp sent an unsupported IrohaConnect message."
        case .sessionExpired:
            return "The IrohaConnect session expired. Connect again from the dApp."
        }
    }
}

final class IrohaConnectSessionService: NSObject {
    weak var delegate: IrohaConnectSessionServiceDelegate?

    let handoff: IrohaConnectWalletURI

    private let accountProvider: IrohaConnectAccountProviding
    private let engine: IrohaConnectProtocolEngine
    private let queue = DispatchQueue(label: "jp.co.soramitsu.fearlesswallet.irohaconnect.session")
    private var urlSession: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var connectTimeout: DispatchWorkItem?
    private var requestTimeout: DispatchWorkItem?
    private var expiryTimeout: DispatchWorkItem?
    private var account: IrohaConnectAccountDescriptor?
    private var isOpen = false
    private var isClosed = false

    init(
        handoff: IrohaConnectWalletURI,
        accountProvider: IrohaConnectAccountProviding = KeychainIrohaConnectAccountProvider(),
        ephemeralPrivateKey: Data? = nil
    ) throws {
        self.handoff = handoff
        self.accountProvider = accountProvider
        engine = try IrohaConnectProtocolEngine(
            handoff: handoff,
            ephemeralPrivateKey: ephemeralPrivateKey
        )
        super.init()
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

    func approveSignature(for account: IrohaConnectAccountDescriptor) {
        queue.async { [weak self] in
            self?.approveSignatureOnQueue(for: account)
        }
    }

    func close() {
        queue.async { [weak self] in
            self?.finish(error: nil)
        }
    }

    private func startOnQueue() {
        guard !isClosed, socket == nil else {
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil

        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.qualityOfService = .userInitiated
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        var request = URLRequest(url: handoff.webSocketURL)
        request.timeoutInterval = 20
        request.setValue(handoff.webSocketSubprotocol, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let task = session.webSocketTask(with: request)
        urlSession = session
        socket = task
        task.resume()

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, !isOpen else { return }
            finish(error: IrohaConnectSessionServiceError.connectTimedOut)
        }
        connectTimeout = timeout
        queue.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    private func approveConnectionOnQueue(for requestedAccount: IrohaConnectAccountDescriptor) {
        guard !isClosed, account == requestedAccount else {
            finish(error: IrohaConnectAccountProviderError.accountMismatch)
            return
        }

        do {
            let preimage = try engine.makeApprovalPreimage(
                accountID: requestedAccount.accountID,
                signingPublicKey: requestedAccount.publicKey
            )
            let signature = try accountProvider.sign(preimage, for: requestedAccount)
            let frame = try engine.makeApprovalFrame(
                accountID: requestedAccount.accountID,
                signingPublicKey: requestedAccount.publicKey,
                signature: signature
            )
            send(frame) { [weak self] in
                guard let self else { return }
                dispatchDelegate { $0.irohaConnectSessionDidApprove(self) }
            }
        } catch {
            finish(error: error)
        }
    }

    private func approveSignatureOnQueue(for requestedAccount: IrohaConnectAccountDescriptor) {
        guard !isClosed, account == requestedAccount else {
            finish(error: IrohaConnectAccountProviderError.accountMismatch)
            return
        }

        do {
            guard let request = currentPendingRequest else {
                throw IrohaConnectError.invalidState
            }
            let signature = try accountProvider.sign(request.message, for: requestedAccount)
            let frame = try engine.makeSignResultFrame(signature: signature)
            requestTimeout?.cancel()
            requestTimeout = nil
            currentPendingRequest = nil
            send(frame) { [weak self] in
                guard let self else { return }
                dispatchDelegate { $0.irohaConnectSessionDidCompleteSignature(self) }
            }
        } catch {
            finish(error: error)
        }
    }

    private var currentPendingRequest: IrohaConnectSignRawRequest?

    private func receiveNext() {
        guard !isClosed, let socket else {
            return
        }

        socket.receive { [weak self] result in
            guard let self else { return }
            queue.async {
                switch result {
                case let .success(message):
                    do {
                        guard case let .data(data) = message else {
                            throw IrohaConnectSessionServiceError.unexpectedMessage
                        }
                        try self.handle(data)
                        self.receiveNext()
                    } catch {
                        self.finish(error: error)
                    }
                case let .failure(error):
                    self.finish(error: error)
                }
            }
        }
    }

    private func handle(_ data: Data) throws {
        let frame = try IrohaConnectWireCodec.decodeFrame(data)
        switch frame.kind {
        case .control(.open):
            let open = try engine.acceptOpenFrame(data)
            let selectedAccount = try accountProvider.selectedAccount()
            account = selectedAccount
            dispatchDelegate { [weak self] delegate in
                guard let self else { return }
                delegate.irohaConnectSession(self, requestsConnection: open, account: selectedAccount)
            }
        case .control(.ping):
            try send(engine.makePongFrame(for: data))
        case .ciphertext:
            guard currentPendingRequest == nil else {
                throw IrohaConnectError.invalidState
            }
            let request = try engine.decryptSignRawRequest(data)
            currentPendingRequest = request
            installRequestTimeout()
            guard let account else {
                throw IrohaConnectAccountProviderError.accountUnavailable
            }
            dispatchDelegate { [weak self] delegate in
                guard let self else { return }
                delegate.irohaConnectSession(self, requestsSignature: request, account: account)
            }
        case .control(.pong):
            throw IrohaConnectSessionServiceError.unexpectedMessage
        }
    }

    private func send(_ data: Data, completion: (() -> Void)? = nil) {
        guard !isClosed, let socket else {
            finish(error: IrohaConnectSessionServiceError.transportUnavailable)
            return
        }

        socket.send(.data(data)) { [weak self] error in
            guard let self else { return }
            queue.async {
                if let error {
                    self.finish(error: error)
                } else {
                    completion?()
                }
            }
        }
    }

    private func installRequestTimeout() {
        requestTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            self?.finish(error: IrohaConnectSessionServiceError.requestTimedOut)
        }
        requestTimeout = timeout
        queue.asyncAfter(deadline: .now() + 90, execute: timeout)
    }

    private func installExpiryTimeout() {
        expiryTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            self?.finish(error: IrohaConnectSessionServiceError.sessionExpired)
        }
        expiryTimeout = timeout
        queue.asyncAfter(deadline: .now() + 15 * 60, execute: timeout)
    }

    private func dispatchDelegate(_ callback: @escaping (IrohaConnectSessionServiceDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let delegate = self?.delegate else { return }
            callback(delegate)
        }
    }

    private func finish(error: Error?) {
        guard !isClosed else {
            return
        }

        isClosed = true
        connectTimeout?.cancel()
        requestTimeout?.cancel()
        expiryTimeout?.cancel()
        connectTimeout = nil
        requestTimeout = nil
        expiryTimeout = nil
        currentPendingRequest = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        dispatchDelegate { [weak self] delegate in
            guard let self else { return }
            delegate.irohaConnectSession(self, didCloseWith: error)
        }
    }
}

extension IrohaConnectSessionService: URLSessionWebSocketDelegate {
    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        queue.async { [weak self] in
            guard let self, !isClosed else { return }
            guard `protocol` == handoff.webSocketSubprotocol else {
                finish(error: IrohaConnectSessionServiceError.authenticationFailed)
                return
            }
            isOpen = true
            connectTimeout?.cancel()
            connectTimeout = nil
            installExpiryTimeout()
            receiveNext()
        }
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith _: URLSessionWebSocketTask.CloseCode,
        reason _: Data?
    ) {
        queue.async { [weak self] in
            guard let self, !isClosed else { return }
            finish(error: IrohaConnectSessionServiceError.transportUnavailable)
        }
    }
}
