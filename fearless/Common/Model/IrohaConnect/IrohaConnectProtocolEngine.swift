import Foundation

/// Why the wallet answered a dApp request without asking the user.
enum IrohaConnectNotice: String, Equatable {
    case rawSigningUnavailable = "raw_signing_unavailable"
    case requestInProgress = "request_in_progress"
    case permissionDenied = "permission_denied"
    case transactionInvalid = "transaction_invalid"
    case transactionUnsupported = "transaction_unsupported"
    case transactionWrongAccount = "transaction_wrong_account"
    case requestExpired = "request_expired"
}

/// A reviewed transaction waiting for the user's decision.
struct IrohaConnectPendingSignature: Equatable {
    let requestID: String
    let account: IrohaConnectAccountDescriptor
    let review: IrohaConnectTransactionReview
    let payloadHash: Data
}

/// The Connect session state machine, without I/O: it consumes relayed frames and produces the frames to send.
/// Sequences are strict per direction, Torii's server events are numbered on their own, and the wallet keeps the
/// session alive only with sequenced Connect Ping frames (Torii closes a socket on any text frame).
final class IrohaConnectProtocolEngine {
    enum Phase: Equatable {
        case connecting
        case sessionApproval
        case connected
        case requestApproval
        case closed
    }

    enum Event: Equatable {
        case openRequested(IrohaConnectOpenFrame)
        case signatureRequested(IrohaConnectPendingSignature)
        case refused(code: String, notice: IrohaConnectNotice)
        case closedByApp
    }

    struct Reaction: Equatable {
        var frames: [Data] = []
        var events: [Event] = []
    }

    static let signTransactionMethod = "sign_transaction"

    let link: IrohaConnectWalletURI
    private(set) var phase = Phase.connecting
    private(set) var open: IrohaConnectOpenFrame?
    private(set) var pending: IrohaConnectPendingSignature?

    /// Last accepted app-to-wallet sequence.
    private var appSequence: UInt64 = 0
    /// Last accepted Torii server-event sequence.
    private var serverSequence: UInt64 = 0
    /// Next wallet-to-app sequence.
    private var walletSequence: UInt64 = 1
    private var pingNonce: UInt64
    private var keys: IrohaConnectDirectionKeys?
    private var account: IrohaConnectAccountDescriptor?
    private let makeRequestID: () -> String

    init(
        link: IrohaConnectWalletURI,
        pingNonce: UInt64 = UInt64.random(in: 0 ... UInt64(UInt32.max)),
        makeRequestID: @escaping () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.link = link
        self.pingNonce = pingNonce
        self.makeRequestID = makeRequestID
    }

    var approvedAccount: IrohaConnectAccountDescriptor? {
        account
    }

    // MARK: - Inbound

    func receive(_ data: Data, accountForOpen: () throws -> IrohaConnectAccountDescriptor) throws -> Reaction {
        guard phase != .closed else {
            return Reaction()
        }
        let frame = try IrohaConnectWireCodec.decodeFrame(data, sessionID: link.sessionID)

        if case .control(.serverEvent) = frame.kind {
            guard frame.sequence == serverSequence + 1 else {
                throw IrohaConnectError.invalidFrame("The relay sent an out-of-order event.")
            }
            serverSequence = frame.sequence
            return Reaction()
        }
        guard frame.direction == .appToWallet else {
            throw IrohaConnectError.invalidFrame("The relay sent a frame in the wrong direction.")
        }
        guard frame.sequence > appSequence else {
            throw IrohaConnectError.invalidFrame("The dApp replayed an IrohaConnect frame.")
        }
        guard frame.sequence == appSequence + 1 else {
            throw IrohaConnectError.invalidFrame("The dApp sent an out-of-order frame.")
        }
        if appSequence == 0 {
            guard case .control(.open) = frame.kind else {
                throw IrohaConnectError.invalidFrame("The dApp sent data before opening the session.")
            }
        }
        appSequence = frame.sequence

        switch frame.kind {
        case let .control(control):
            return try handleControl(control, accountForOpen: accountForOpen)
        case let .ciphertext(aead):
            return try handleCiphertext(aead, sequence: frame.sequence, direction: frame.direction)
        }
    }

    private func handleControl(
        _ control: IrohaConnectControl,
        accountForOpen: () throws -> IrohaConnectAccountDescriptor
    ) throws -> Reaction {
        switch control {
        case let .open(open):
            guard phase == .connecting, appSequence == 1 else {
                throw IrohaConnectError.invalidFrame("The dApp sent an unexpected Open frame.")
            }
            guard open.appPublicKey == link.appPublicKey else {
                throw IrohaConnectError.invalidFrame("The Open frame does not match the IrohaConnect link.")
            }
            guard open.networkID == link.networkID.bytes else {
                throw IrohaConnectError.invalidFrame("The Open frame is for a different network.")
            }
            account = try accountForOpen()
            self.open = open
            phase = .sessionApproval
            return Reaction(events: [.openRequested(open)])
        case let .ping(nonce):
            return Reaction(frames: [try nextFrame { sequence in
                try IrohaConnectWireCodec.encodePongFrame(sessionID: link.sessionID, sequence: sequence, nonce: nonce)
            }])
        case .pong:
            return Reaction()
        case .close:
            phase = .closed
            return Reaction(events: [.closedByApp])
        case .reject, .serverEvent:
            throw IrohaConnectError.invalidFrame("The dApp sent an unsupported IrohaConnect control.")
        }
    }

    private func handleCiphertext(_ aead: Data, sequence: UInt64, direction: IrohaConnectDirection) throws -> Reaction {
        guard let keys, let account, phase == .connected || phase == .requestApproval else {
            throw IrohaConnectError.invalidFrame("The dApp sent a request before wallet approval.")
        }
        let payload = try IrohaConnectWireCodec.openEnvelope(
            keys: keys,
            sessionID: link.sessionID,
            sequence: sequence,
            direction: direction,
            aead: aead
        )
        switch payload {
        case let .signRequestTransaction(transaction):
            return try handleTransactionRequest(transaction, account: account)
        case .signRequestRaw:
            // Raw requests are signed only by the account's registered off-chain signing key, inside the off-chain
            // envelope, so a dApp can never obtain a transaction signature this way. Fearless accounts have no such
            // key registered, so the request is refused without signing anything.
            return try refuse(
                code: "SIGNING_KEY_REQUIRED",
                message: "This account has no registered off-chain signing key. Fearless never signs raw bytes with the account key.",
                notice: .rawSigningUnavailable
            )
        case .close, .reject:
            phase = .closed
            return Reaction(events: [.closedByApp])
        case .unknown:
            return Reaction()
        }
    }

    private func handleTransactionRequest(_ transaction: Data, account: IrohaConnectAccountDescriptor) throws -> Reaction {
        guard pending == nil else {
            return try refuse(code: "REQUEST_IN_FLIGHT", message: "Another transaction is being reviewed.", notice: .requestInProgress)
        }
        if let permissions = open?.permissions, !permissions.methods.contains(Self.signTransactionMethod) {
            return try refuse(
                code: "PERMISSION_DENIED",
                message: "The session did not ask to sign transactions.",
                notice: .permissionDenied
            )
        }

        let reviewed: IrohaConnectReviewedTransaction
        do {
            reviewed = try IrohaConnectTransactionReviewer.review(
                transaction,
                expectation: IrohaConnectTransactionExpectation(
                    networkID: link.networkID,
                    networkPrefix: link.profile.networkPrefix,
                    authority: account.accountID,
                    signingPublicKey: account.publicKey
                )
            )
        } catch let error as IrohaConnectTransactionError {
            let notice: IrohaConnectNotice
            switch error {
            case .unsupported:
                notice = .transactionUnsupported
            case .wrongAuthority:
                notice = .transactionWrongAccount
            case .invalid, .wrongNetwork:
                notice = .transactionInvalid
            }
            return try refuse(code: error.resultCode, message: error.detail, notice: notice)
        }

        let request = IrohaConnectPendingSignature(
            requestID: makeRequestID(),
            account: account,
            review: reviewed.review,
            payloadHash: reviewed.payloadHash
        )
        pending = request
        phase = .requestApproval
        return Reaction(events: [.signatureRequested(request)])
    }

    private func refuse(code: String, message: String, notice: IrohaConnectNotice) throws -> Reaction {
        let frame = try sealed(.signResultError(code: code, message: irohaConnectSanitizedReviewText(message, maximum: 480)))
        return Reaction(frames: [frame], events: [.refused(code: code, notice: notice)])
    }

    // MARK: - Wallet decisions

    /// The wallet-built bytes the account key signs to approve the session; never dApp-chosen bytes.
    func approvalPreimage(walletKeyPair: IrohaConnectWalletKeyPair) throws -> Data {
        guard phase == .sessionApproval, let open, let account else {
            throw IrohaConnectError.invalidFrame("That IrohaConnect action is not available.")
        }
        return try IrohaConnectWireCodec.approvalPreimage(IrohaConnectWireCodec.ApprovalInput(
            sessionID: link.sessionID,
            networkID: link.networkID.bytes,
            appPublicKey: link.appPublicKey,
            walletPublicKey: walletKeyPair.publicKey,
            accountID: account.accountID,
            permissionsField: open.permissionsField,
            relayToken: link.relayToken
        ))
    }

    func approveSession(walletKeyPair: IrohaConnectWalletKeyPair, signature: Data) throws -> Data {
        guard phase == .sessionApproval, let open, let account else {
            throw IrohaConnectError.invalidFrame("That IrohaConnect action is not available.")
        }
        let keys = try IrohaConnectDirectionKeys(
            walletKeyPair: walletKeyPair,
            appPublicKey: link.appPublicKey,
            sessionID: link.sessionID
        )
        let frame = try nextFrame { sequence in
            try IrohaConnectWireCodec.encodeApproveFrame(
                sessionID: link.sessionID,
                sequence: sequence,
                walletPublicKey: walletKeyPair.publicKey,
                accountID: account.accountID,
                permissionsField: open.permissionsField,
                signature: signature
            )
        }
        self.keys = keys
        phase = .connected
        return frame
    }

    func rejectSession(reason: String = "The wallet user rejected the connection.") throws -> Data {
        guard phase == .sessionApproval else {
            throw IrohaConnectError.invalidFrame("That IrohaConnect action is not available.")
        }
        let frame = try nextFrame { sequence in
            try IrohaConnectWireCodec.encodeRejectFrame(
                sessionID: link.sessionID,
                sequence: sequence,
                code: 4001,
                codeID: "user_rejected",
                reason: reason
            )
        }
        phase = .closed
        return frame
    }

    func approveRequest(_ requestID: String, signature: Data) throws -> Data {
        guard phase == .requestApproval, let pending, pending.requestID == requestID else {
            throw IrohaConnectError.invalidFrame("The signature request is no longer available.")
        }
        let frame = try sealed(.signResultOK(signature: signature))
        self.pending = nil
        phase = .connected
        return frame
    }

    func rejectRequest(_ requestID: String) throws -> Data {
        try finishRequest(requestID, code: "USER_REJECTED", message: "The wallet user rejected the transaction.")
    }

    func expireRequest(_ requestID: String) throws -> Data {
        try finishRequest(requestID, code: "REQUEST_EXPIRED", message: "The wallet approval timed out.")
    }

    private func finishRequest(_ requestID: String, code: String, message: String) throws -> Data {
        guard let pending, pending.requestID == requestID else {
            throw IrohaConnectError.invalidFrame("The signature request is no longer available.")
        }
        let frame = try sealed(.signResultError(code: code, message: message))
        self.pending = nil
        phase = .connected
        return frame
    }

    /// The next keepalive, or nil when the session has nothing to keep alive.
    func keepAlivePing() throws -> Data? {
        guard phase == .sessionApproval || phase == .connected || phase == .requestApproval else {
            return nil
        }
        pingNonce &+= 1
        let nonce = pingNonce
        return try nextFrame { sequence in
            try IrohaConnectWireCodec.encodePingFrame(sessionID: link.sessionID, sequence: sequence, nonce: nonce)
        }
    }

    /// The final frame when the wallet ends the session, then the engine is closed.
    func disconnect() -> Data? {
        defer {
            phase = .closed
            pending = nil
            keys = nil
        }
        if keys != nil, phase != .closed {
            return try? sealed(.close(code: 1000, reason: "The wallet disconnected.", retryable: false))
        }
        if phase == .sessionApproval {
            return try? rejectSession(reason: "The wallet user cancelled the connection.")
        }
        return nil
    }

    private func sealed(_ payload: IrohaConnectWalletPayload) throws -> Data {
        guard let keys else {
            throw IrohaConnectError.invalidFrame("The IrohaConnect session is not approved.")
        }
        return try nextFrame { sequence in
            try IrohaConnectWireCodec.sealEnvelope(keys: keys, sessionID: link.sessionID, sequence: sequence, payload: payload)
        }
    }

    private func nextFrame(_ encode: (UInt64) throws -> Data) throws -> Data {
        let frame = try encode(walletSequence)
        walletSequence += 1
        return frame
    }
}
