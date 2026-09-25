import Foundation
import BigInt
import TonAPI
import TonSwift

protocol TonTransferRemoteProtocol: Sendable {
    var reviewedSignedOperationOrigin: String? { get }
    func jettonWallet(ownerAddress: String, assetAddress: String, amount: String, precision: Int) async throws -> TonResolvedJettonWallet
    func walletState(address: String) async throws -> TonWalletRemoteState
    func recipientRequiresMemo(address: String) async throws -> Bool
    func emulateUnsigned(
        message: TonUnsignedEmulationMessage,
        intent: TonEmulationIntent
    ) async throws -> TonEmulationResult
    func emulateSigned(
        message: TonSignedExternalMessage,
        intent: TonEmulationIntent
    ) async throws -> TonEmulationResult
    func broadcast(message: TonSignedExternalMessage) async throws
    func reconcile(
        message: TonSignedExternalMessage,
        intent: TonEmulationIntent
    ) async throws -> TonReconciliationResult
}

extension TonTransferRemoteProtocol {
    var reviewedSignedOperationOrigin: String? { nil }
    func jettonWallet(ownerAddress _: String, assetAddress _: String, amount _: String, precision _: Int) async throws -> TonResolvedJettonWallet {
        throw TonTransferTransactionBuilderError.unsupportedAsset
    }
}

struct TonResolvedJettonWallet: Equatable, Sendable {
    let masterAddress: String
    let walletAddress: String
}

enum TonReconciliationResult: Equatable, Sendable {
    case confirmed
    case notFound
}

struct TonEmulationIntent: Equatable, Sendable {
    let senderAddress: String
    let recipientAddress: String
    let amountNanotons: Int64
    let bounce: Bool
    let messageBodyHashHex: String
    let jetton: TonJettonTransferDetails?
    let tonConnect: TonConnectTransferRequest?

    init(request: TonNativeTransferDetails) throws {
        let identity = try TonTransferIntentIdentity(request: request)
        guard let amount = Int64(identity.amountNanotons),
              amount > 0 || identity.tonConnect != nil
        else {
            throw TonTransferTransactionBuilderError.invalidAmount
        }
        senderAddress = identity.sender
        recipientAddress = identity.recipient
        amountNanotons = amount
        bounce = identity.bounce
        messageBodyHashHex = try identity.tonConnect.map { try $0.bindingHashHex() } ?? TonTransferTransactionBuilder.messageBodyHashHex(
            comment: identity.comment, jetton: identity.jetton, senderAddress: identity.sender
        )
        jetton = identity.jetton
        tonConnect = identity.tonConnect
    }
}

struct TonWalletRemoteState: Equatable, Sendable {
    let sequenceNumber: UInt64
    let isInitialized: Bool
}

struct TonEmulationResult: Equatable, Sendable {
    let accepted: Bool
    let totalFeeNanotons: UInt64?
    var executionEffects: TonConnectExecutionEffects?
}

struct TonNativeSendRequest: Equatable, Sendable {
    let asset: TonTransferAsset
    let network: TonTransferNetwork
    let mnemonic: String
    let legacyNativePrivateKey: Data?
    let passphrase: String
    let derivationPath: String
    let senderAddress: String
    let recipientAddress: String
    let amountNanotons: String
    let bounce: Bool
    let comment: String?
    let jetton: TonJettonTransferDetails?
    let tonConnect: TonConnectTransferRequest?

    init(
        asset: TonTransferAsset = .nativeTon,
        network: TonTransferNetwork = .mainnet,
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.tonDefault,
        senderAddress: String,
        recipientAddress: String,
        amountNanotons: String,
        bounce: Bool,
        comment: String? = nil,
        legacyNativePrivateKey: Data? = nil,
        jetton: TonJettonTransferDetails? = nil,
        tonConnect: TonConnectTransferRequest? = nil
    ) {
        self.asset = asset
        self.network = network
        self.mnemonic = mnemonic
        self.legacyNativePrivateKey = legacyNativePrivateKey
        self.passphrase = passphrase
        self.derivationPath = derivationPath
        self.senderAddress = senderAddress
        self.recipientAddress = recipientAddress
        self.amountNanotons = amountNanotons
        self.bounce = bounce
        self.comment = comment
        self.jetton = jetton
        self.tonConnect = tonConnect
    }
}

struct TonSigningCredentials: Equatable, Sendable {
    let mnemonic: String
    let legacyNativePrivateKey: Data?
    let passphrase: String
    let derivationPath: String

    init(
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.tonDefault,
        legacyNativePrivateKey: Data? = nil
    ) {
        self.mnemonic = mnemonic
        self.legacyNativePrivateKey = legacyNativePrivateKey
        self.passphrase = passphrase
        self.derivationPath = derivationPath
    }
}

struct TonNativeEstimateRequest: Equatable, Sendable {
    let asset: TonTransferAsset
    let network: TonTransferNetwork
    let publicKey: Data
    let senderAddress: String
    let recipientAddress: String
    let amountNanotons: String
    let bounce: Bool
    let comment: String?
    let jetton: TonJettonTransferDetails?
    let tonConnect: TonConnectTransferRequest?

    init(
        asset: TonTransferAsset = .nativeTon,
        network: TonTransferNetwork = .mainnet,
        publicKey: Data,
        senderAddress: String,
        recipientAddress: String,
        amountNanotons: String,
        bounce: Bool,
        comment: String? = nil,
        jetton: TonJettonTransferDetails? = nil,
        tonConnect: TonConnectTransferRequest? = nil
    ) {
        self.asset = asset
        self.network = network
        self.publicKey = publicKey
        self.senderAddress = senderAddress
        self.recipientAddress = recipientAddress
        self.amountNanotons = amountNanotons
        self.bounce = bounce
        self.comment = comment
        self.jetton = jetton
        self.tonConnect = tonConnect
    }
}

protocol TonNativeTransferDetails {
    var asset: TonTransferAsset { get }
    var network: TonTransferNetwork { get }
    var senderAddress: String { get }
    var recipientAddress: String { get }
    var amountNanotons: String { get }
    var bounce: Bool { get }
    var comment: String? { get }
    var jetton: TonJettonTransferDetails? { get }
    var tonConnect: TonConnectTransferRequest? { get }
}

extension TonNativeTransferDetails { var tonConnect: TonConnectTransferRequest? { nil } }
extension TonNativeSendRequest: TonNativeTransferDetails {}
extension TonNativeEstimateRequest: TonNativeTransferDetails {}

struct TonPreparedTransferTransaction: Equatable, Sendable {
    let signedMessage: TonSignedExternalMessage
    let walletState: TonWalletRemoteState
    let emulation: TonEmulationResult
}

struct TonEstimatedTransferTransaction: Equatable, Sendable {
    let emulationMessage: TonUnsignedEmulationMessage
    let walletState: TonWalletRemoteState
    let emulation: TonEmulationResult
    let templateCreatedAt: UInt64
}

struct TonSentTransferTransaction: Equatable, Sendable {
    let prepared: TonPreparedTransferTransaction
    let messageHashHex: String
}

enum TonSendServiceError: Error, Equatable {
    case productionSendDisabled
    case invalidAccount
    case invalidClock
    case inconsistentWalletState
    case emulationRejected
    case invalidEmulationFee
    case recipientMemoRequired
    case walletStateTimedOut
    case recipientInspectionTimedOut
    case emulationTimedOut
    case broadcastTimedOut
    case reconciliationTimedOut
    case feeQuoteRequired
    case feeQuoteMismatch
    case feeQuoteExpired
    case untrustedFeeQuoteEndpoint
    case walletStateChangedSinceQuote
    case feeChangedAfterConfirmation(quoted: UInt64, signedEmulation: UInt64)
    case sendAlreadyInFlight(senderAddress: String)
    case differentPendingIntent(senderAddress: String)
    case priorIntentConfirmed(identity: TonTransferIntentIdentity, messageHashHex: String)
    case broadcastOutcomeUnknown(messageHashHex: String)
}

struct TonTransferIntentIdentity: Equatable, Hashable, Sendable {
    let sender: String
    let recipient: String
    let amountNanotons: String
    let bounce: Bool
    let comment: String?
    let jetton: TonJettonTransferDetails?
    let tonConnect: TonConnectTransferRequest?

    var network: TonTransferNetwork { tonConnect?.network ?? .mainnet }
    var coordinationKey: String { network == .testnet ? "testnet:" + sender : sender }
    var asset: TonTransferAsset { tonConnect != nil ? .tonConnect : (jetton.map { .jetton(masterAddress: $0.masterAddress) } ?? .nativeTon) }

    init(request: TonNativeTransferDetails) throws {
        try TonTransferTransactionBuilder.validateSupportedScope(asset: request.asset, network: request.network, jetton: request.jetton, tonConnect: request.tonConnect)
        guard request.amountNanotons.utf8.count <= 19 else {
            throw TonTransferTransactionBuilderError.invalidAmount
        }
        if let comment = request.comment,
           comment.utf8.count > TonTransferTransactionBuilder.maximumCommentBytes {
            throw TonTransferTransactionBuilderError.invalidComment
        }
        guard request.senderAddress.utf8.count <= TonTransferTransactionBuilder.maximumAddressInputBytes else {
            throw TonTransferTransactionBuilderError.invalidSenderAddress
        }
        do {
            sender = try TonSwift.Address.parse(request.senderAddress).toRaw()
        } catch {
            throw TonTransferTransactionBuilderError.invalidSenderAddress
        }
        guard request.recipientAddress.utf8.count <= TonTransferTransactionBuilder.maximumAddressInputBytes else {
            throw TonTransferTransactionBuilderError.invalidRecipientAddress
        }
        do {
            recipient = try TonSwift.Address.parse(request.recipientAddress).toRaw()
        } catch {
            throw TonTransferTransactionBuilderError.invalidRecipientAddress
        }
        amountNanotons = request.amountNanotons
        bounce = request.bounce
        comment = request.comment
        jetton = request.jetton
        tonConnect = request.tonConnect
    }
}

struct TonPendingSignedIntent: Equatable, Sendable {
    let identity: TonTransferIntentIdentity
    let intent: TonEmulationIntent
    let message: TonSignedExternalMessage
    let walletState: TonWalletRemoteState
    let feeQuote: TonTransferFeeQuote?
    var emulation: TonEmulationResult?
    var confirmed: Bool = false
}

actor TonPendingIntentCoordinator {
    enum BeginResult: Sendable {
        case fresh
        case retry(TonPendingSignedIntent)
        case recoverDifferent(TonPendingSignedIntent)
    }

    static let shared = TonPendingIntentCoordinator(
        journal: TonKeychainPendingIntentJournal()
    )

    private enum State {
        case preparing(TonTransferIntentIdentity)
        case pending(TonPendingSignedIntent)
        case retrying(TonPendingSignedIntent)
    }

    private let journal: TonPendingIntentJournaling
    private var statesBySender: [String: State] = [:]

    init(journal: TonPendingIntentJournaling) {
        self.journal = journal
    }

    #if DEBUG
        init() {
            journal = TonInMemoryPendingIntentJournal()
        }
    #endif

    func pending(senderRaw: String) throws -> TonPendingSignedIntent? {
        switch statesBySender[senderRaw] {
        case let .pending(pending), let .retrying(pending): return pending
        case .preparing: return nil
        case .none: return try journal.load(senderRaw: senderRaw)
        }
    }

    func begin(_ identity: TonTransferIntentIdentity) throws -> BeginResult {
        if statesBySender[identity.coordinationKey] == nil,
           let persisted = try journal.load(senderRaw: identity.coordinationKey) {
            statesBySender[identity.coordinationKey] = .pending(persisted)
        }

        guard let state = statesBySender[identity.coordinationKey] else {
            statesBySender[identity.coordinationKey] = .preparing(identity)
            return .fresh
        }

        switch state {
        case let .preparing(existing):
            if existing == identity {
                throw TonSendServiceError.sendAlreadyInFlight(senderAddress: identity.sender)
            }
            throw TonSendServiceError.differentPendingIntent(senderAddress: identity.sender)
        case let .pending(pending):
            statesBySender[identity.coordinationKey] = .retrying(pending)
            return pending.identity == identity ? .retry(pending) : .recoverDifferent(pending)
        case let .retrying(pending):
            if pending.identity == identity {
                throw TonSendServiceError.sendAlreadyInFlight(senderAddress: identity.sender)
            }
            throw TonSendServiceError.differentPendingIntent(senderAddress: identity.sender)
        }
    }

    func reserve(_ pending: TonPendingSignedIntent) throws {
        guard case let .preparing(identity) = statesBySender[pending.identity.coordinationKey],
              identity == pending.identity
        else {
            throw TonSendServiceError.sendAlreadyInFlight(senderAddress: pending.identity.sender)
        }
        try journal.save(pending)
        statesBySender[pending.identity.coordinationKey] = .pending(pending)
    }

    func recordEmulation(
        _ emulation: TonEmulationResult,
        for identity: TonTransferIntentIdentity
    ) throws {
        let storedPending: TonPendingSignedIntent
        let isRetrying: Bool
        switch statesBySender[identity.coordinationKey] {
        case let .pending(value):
            storedPending = value
            isRetrying = false
        case let .retrying(value):
            storedPending = value
            isRetrying = true
        default:
            throw TonSendServiceError.sendAlreadyInFlight(senderAddress: identity.sender)
        }
        guard storedPending.identity == identity else {
            throw TonSendServiceError.differentPendingIntent(senderAddress: identity.sender)
        }
        var updatedPending = storedPending
        updatedPending.emulation = emulation
        try journal.save(updatedPending)
        statesBySender[identity.coordinationKey] = isRetrying ? .retrying(updatedPending) : .pending(updatedPending)
    }

    func recordConfirmed(_ pending: TonPendingSignedIntent) throws -> TonPendingSignedIntent {
        let storedPending: TonPendingSignedIntent
        switch statesBySender[pending.identity.coordinationKey] {
        case let .pending(value), let .retrying(value):
            storedPending = value
        default:
            throw TonSendServiceError.sendAlreadyInFlight(senderAddress: pending.identity.sender)
        }
        guard storedPending.identity == pending.identity,
              storedPending.message.messageHashHex == pending.message.messageHashHex
        else {
            throw TonSendServiceError.differentPendingIntent(senderAddress: pending.identity.sender)
        }
        var confirmedPending = storedPending
        confirmedPending.confirmed = true
        try journal.save(confirmedPending)
        statesBySender[pending.identity.coordinationKey] = .pending(confirmedPending)
        return confirmedPending
    }

    func retainPending(_ pending: TonPendingSignedIntent) throws {
        let storedPending: TonPendingSignedIntent
        switch statesBySender[pending.identity.coordinationKey] {
        case let .pending(value), let .retrying(value):
            storedPending = value
        default:
            throw TonSendServiceError.sendAlreadyInFlight(senderAddress: pending.identity.sender)
        }
        guard storedPending.identity == pending.identity,
              storedPending.message.messageHashHex == pending.message.messageHashHex
        else {
            throw TonSendServiceError.differentPendingIntent(senderAddress: pending.identity.sender)
        }

        // Recovery tasks may finish after another task has durably confirmed this bearer.
        // Preserve the most advanced phase and write it before changing actor state so a
        // failed durable write can never leave memory ahead of the journal.
        let retained: TonPendingSignedIntent
        if storedPending.confirmed ||
            (storedPending.emulation != nil && pending.emulation == nil) {
            retained = storedPending
        } else {
            retained = pending
        }
        try journal.save(retained)
        statesBySender[pending.identity.coordinationKey] = .pending(retained)
    }

    func abortBeforeExposure(_ identity: TonTransferIntentIdentity) {
        guard case let .preparing(existing) = statesBySender[identity.coordinationKey],
              existing == identity
        else {
            return
        }
        statesBySender.removeValue(forKey: identity.coordinationKey)
    }

    func acknowledgeConfirmed(
        senderRaw: String,
        identity: TonTransferIntentIdentity,
        messageHashHex: String
    ) throws {
        if statesBySender[senderRaw] == nil,
           let persisted = try journal.load(senderRaw: senderRaw) {
            statesBySender[senderRaw] = .pending(persisted)
        }
        let pending: TonPendingSignedIntent
        switch statesBySender[senderRaw] {
        case let .pending(value), let .retrying(value):
            pending = value
        default:
            throw TonSendServiceError.sendAlreadyInFlight(senderAddress: senderRaw)
        }
        guard pending.confirmed,
              pending.identity == identity,
              pending.message.messageHashHex == messageHashHex
        else {
            throw TonSendServiceError.differentPendingIntent(senderAddress: senderRaw)
        }
        try journal.delete(
            senderRaw: senderRaw,
            expectedMessageHashHex: pending.message.messageHashHex
        )
        statesBySender.removeValue(forKey: senderRaw)
    }
}

/// Coordinates a native TON transfer while keeping network access behind an injectable seam.
///
/// Asset/network/key/address validation is completed locally before the first remote call.
/// The exact signed BOC accepted by emulation is then broadcast without reserialization.
final class TonSendService: @unchecked Sendable {
    static let defaultMessageLifetimeSeconds: UInt64 = 120
    static let defaultRemoteTimeoutNanoseconds: UInt64 = 15_000_000_000
    /// A single Wallet V4 native transfer must never consume more than one TON in fees.
    static let defaultMaximumFeeNanotons: UInt64 = 1_000_000_000

    private let remote: TonTransferRemoteProtocol
    private let clock: @Sendable() -> UInt64
    private let messageLifetimeSeconds: UInt64
    private let remoteTimeoutNanoseconds: UInt64
    private let maximumFeeNanotons: UInt64
    private let pendingCoordinator: TonPendingIntentCoordinator

    init(
        remote: TonTransferRemoteProtocol,
        messageLifetimeSeconds: UInt64 = TonSendService.defaultMessageLifetimeSeconds,
        remoteTimeoutNanoseconds: UInt64 = TonSendService.defaultRemoteTimeoutNanoseconds,
        maximumFeeNanotons: UInt64 = TonSendService.defaultMaximumFeeNanotons,
        pendingCoordinator: TonPendingIntentCoordinator = .shared,
        clock: @escaping @Sendable() -> UInt64 = { UInt64(Date().timeIntervalSince1970) }
    ) {
        self.remote = remote
        self.messageLifetimeSeconds = messageLifetimeSeconds
        self.remoteTimeoutNanoseconds = remoteTimeoutNanoseconds
        self.maximumFeeNanotons = maximumFeeNanotons
        self.pendingCoordinator = pendingCoordinator
        self.clock = clock
    }

    private struct BuiltSignedTransfer {
        let identity: TonTransferIntentIdentity
        let intent: TonEmulationIntent
        let message: TonSignedExternalMessage
        let walletState: TonWalletRemoteState
    }

    /// A persisted transfer stays recoverable even after a full-balance token send or
    /// when an account-balance request is unavailable following restart.
    func resolveJettonWallet(ownerAddress: String, assetAddress: String, recipientAddress: String, amount: String, precision: Int) async throws -> TonResolvedJettonWallet {
        let owner = try TonTransferTransactionBuilder.canonicalMainnetAddress(ownerAddress, basechainOnly: true)
        let asset = try TonTransferTransactionBuilder.canonicalMainnetAddress(assetAddress, basechainOnly: true)
        let recipient = try TonTransferTransactionBuilder.canonicalMainnetAddress(recipientAddress)
        _ = try TonTransferTransactionBuilder.parseAmount(amount)
        if let pending = try await pendingCoordinator.pending(senderRaw: owner),
           let jetton = pending.identity.jetton,
           jetton.recipientAddress == recipient, jetton.amount == amount,
           asset == jetton.masterAddress || asset == pending.identity.recipient {
            return TonResolvedJettonWallet(masterAddress: jetton.masterAddress, walletAddress: pending.identity.recipient)
        }
        return try await withRemoteTimeout(error: .recipientInspectionTimedOut) {
            try await self.remote.jettonWallet(ownerAddress: owner, assetAddress: asset, amount: amount, precision: precision)
        }
    }

    func estimate(_ request: TonNativeEstimateRequest) async throws -> TonEstimatedTransferTransaction {
        let (now, validUntil) = try validatedTiming(for: request)
        if request.tonConnect != nil { try requireNetworkOrigin(request.network) }
        let intent = try TonEmulationIntent(request: request)
        let provisionalRequest = transactionRequest(
            from: request,
            sequenceNumber: 0,
            includeStateInit: false,
            validUntil: validUntil
        )

        // The preview has no access to mnemonic/private material and carries an invalid
        // signature even during local preflight.
        _ = try TonTransferTransactionBuilder.buildForFeeEstimation(
            request: provisionalRequest,
            publicKey: request.publicKey,
            now: now
        )
        try await inspectRecipients(request)

        let walletState = try await loadWalletState(senderAddress: request.senderAddress)
        let emulationMessage = try TonTransferTransactionBuilder.buildForFeeEstimation(
            request: transactionRequest(
                from: request,
                sequenceNumber: walletState.sequenceNumber,
                includeStateInit: !walletState.isInitialized,
                validUntil: validUntil
            ),
            publicKey: request.publicKey,
            now: now
        )
        let emulation = try await withRemoteTimeout(error: .emulationTimedOut) {
            try await self.remote.emulateUnsigned(
                message: emulationMessage,
                intent: intent
            )
        }
        try validateEmulation(emulation)
        return TonEstimatedTransferTransaction(
            emulationMessage: emulationMessage,
            walletState: walletState,
            emulation: emulation,
            templateCreatedAt: now
        )
    }

    /// Produces the exact short-lived quote displayed by confirmation. Unlike an advisory
    /// estimate, a submission quote is available only on the binary-reviewed send origin.
    func quote(_ request: TonNativeEstimateRequest) async throws -> TonTransferFeeQuote {
        guard let endpointOrigin = remote.reviewedSignedOperationOrigin else {
            throw TonSendServiceError.untrustedFeeQuoteEndpoint
        }
        let estimated = try await estimate(request)
        guard let feeNanotons = estimated.emulation.totalFeeNanotons else {
            throw TonSendServiceError.invalidEmulationFee
        }
        let issuedAt = clock()
        let validUntil = estimated.emulationMessage.validUntil
        guard issuedAt >= estimated.templateCreatedAt,
              issuedAt < validUntil,
              validUntil - issuedAt > TonTransferTransactionBuilder.minimumLifetimeSeconds
        else {
            throw TonSendServiceError.feeQuoteExpired
        }
        let latestQuoteExpiry = validUntil - TonTransferTransactionBuilder.minimumLifetimeSeconds
        let ageBoundExpiry = issuedAt + TonTransferFeeQuote.maximumAgeSeconds
        let expiresAt = min(latestQuoteExpiry, ageBoundExpiry)
        guard expiresAt > issuedAt else {
            throw TonSendServiceError.feeQuoteExpired
        }

        let identity = try TonTransferIntentIdentity(request: request)
        let intent = try TonEmulationIntent(request: request)
        let transaction = TonTransferTransactionRequest(
            asset: request.asset,
            network: request.network,
            senderAddress: identity.sender,
            recipientAddress: identity.recipient,
            amountNanotons: identity.amountNanotons,
            sequenceNumber: estimated.walletState.sequenceNumber,
            includeStateInit: !estimated.walletState.isInitialized,
            validUntil: validUntil,
            bounce: identity.bounce,
            comment: identity.comment,
            jetton: identity.jetton,
            tonConnect: identity.tonConnect
        )
        return try TonTransferFeeQuote(
            templateCreatedAt: estimated.templateCreatedAt,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            endpointOrigin: endpointOrigin,
            publicKey: request.publicKey,
            identity: identity,
            intent: intent,
            transactionRequest: transaction,
            walletState: estimated.walletState,
            unsignedMessage: estimated.emulationMessage,
            feeNanotons: feeNanotons,
            executionEffects: estimated.emulation.executionEffects
        )
    }

    func send(
        _ request: TonNativeSendRequest,
        feeQuote: TonTransferFeeQuote? = nil
    ) async throws -> TonSentTransferTransaction {
        #if !DEBUG
            guard request.legacyNativePrivateKey != nil else {
                throw TonSendServiceError.productionSendDisabled
            }
        #endif
        return try await performSend(
            request,
            feeQuote: feeQuote,
            requiresFeeQuote: true,
            signingCredentials: {
                TonSigningCredentials(
                    mnemonic: request.mnemonic,
                    passphrase: request.passphrase,
                    derivationPath: request.derivationPath,
                    legacyNativePrivateKey: request.legacyNativePrivateKey
                )
            }
        )
    }

    /// Submission entry point used by the wallet integration. Pending journal recovery is
    /// resolved before the closure is invoked, so a previously exposed BOC remains recoverable
    /// even when mnemonic material is temporarily unavailable.
    func send(
        _ request: TonNativeEstimateRequest,
        feeQuote: TonTransferFeeQuote?,
        legacyAccount: LegacyTonAccount? = nil,
        signingCredentials: @escaping () throws -> TonSigningCredentials
    ) async throws -> TonSentTransferTransaction {
        #if !DEBUG
            guard let nativeAccount = legacyAccount, nativeAccount.publicKey == request.publicKey,
                  try TonSwift.Address.parse(nativeAccount.address).toRaw() == TonSwift.Address.parse(request.senderAddress).toRaw()
            else { throw TonSendServiceError.productionSendDisabled }
        #endif
        return try await performSend(
            request,
            feeQuote: feeQuote,
            requiresFeeQuote: true,
            signingCredentials: {
                let credentials = try signingCredentials()
                if let legacyAccount {
                    guard let key = credentials.legacyNativePrivateKey else { throw TonSendServiceError.invalidAccount }
                    _ = try legacyAccount.validatedPrivateKey(key)
                }
                return credentials
            }
        )
    }

    #if DEBUG
        /// Explicitly test-only compatibility seam for low-level validation/timeout tests.
        /// Application integration always uses the quote-required `send` API.
        func sendUnquotedForTesting(
            _ request: TonNativeSendRequest
        ) async throws -> TonSentTransferTransaction {
            try await performSend(
                request,
                feeQuote: nil,
                requiresFeeQuote: false,
                signingCredentials: {
                    TonSigningCredentials(
                        mnemonic: request.mnemonic,
                        passphrase: request.passphrase,
                        derivationPath: request.derivationPath,
                        legacyNativePrivateKey: request.legacyNativePrivateKey
                    )
                }
            )
        }

    #endif

    private func performSend(
        _ request: any TonNativeTransferDetails,
        feeQuote: TonTransferFeeQuote?,
        requiresFeeQuote: Bool,
        signingCredentials: () throws -> TonSigningCredentials
    ) async throws -> TonSentTransferTransaction {
        let identity = try TonTransferIntentIdentity(request: request)
        switch try await pendingCoordinator.begin(identity) {
        case let .retry(pending):
            try await requireStoredEndpointForRecovery(pending)
            if requiresFeeQuote {
                return try await recoverPendingWithoutRebroadcast(pending)
            }
            return try await retry(pending)
        case let .recoverDifferent(pending):
            try await requireStoredEndpointForRecovery(pending)
            return try await recoverDifferentPending(pending)
        case .fresh:
            break
        }

        if requiresFeeQuote, feeQuote == nil {
            await pendingCoordinator.abortBeforeExposure(identity)
            throw TonSendServiceError.feeQuoteRequired
        }

        let built: BuiltSignedTransfer
        let emulatedPending: TonPendingSignedIntent
        do {
            let credentials = try signingCredentials()
            let signingRequest = TonNativeSendRequest(
                asset: request.asset,
                network: request.network,
                mnemonic: credentials.mnemonic,
                passphrase: credentials.passphrase,
                derivationPath: credentials.derivationPath,
                senderAddress: request.senderAddress,
                recipientAddress: request.recipientAddress,
                amountNanotons: request.amountNanotons,
                bounce: request.bounce,
                comment: request.comment,
                legacyNativePrivateKey: credentials.legacyNativePrivateKey,
                jetton: request.jetton,
                tonConnect: request.tonConnect
            )
            built = try await buildSignedTransfer(
                signingRequest,
                identity: identity,
                feeQuote: feeQuote
            )
            try await pendingCoordinator.reserve(
                TonPendingSignedIntent(
                    identity: identity,
                    intent: built.intent,
                    message: built.message,
                    walletState: built.walletState,
                    feeQuote: feeQuote,
                    emulation: nil
                )
            )
        } catch {
            await pendingCoordinator.abortBeforeExposure(identity)
            throw error
        }

        do {
            let emulation = try await withRemoteTimeout(error: .emulationTimedOut) {
                try await self.remote.emulateSigned(
                    message: built.message,
                    intent: built.intent
                )
            }
            try validateEmulation(emulation)
            guard emulation.executionEffects == feeQuote?.executionEffects else { throw TonSendServiceError.feeQuoteMismatch }
            if let feeQuote,
               emulation.totalFeeNanotons != feeQuote.feeNanotons {
                throw TonSendServiceError.feeChangedAfterConfirmation(
                    quoted: feeQuote.feeNanotons,
                    signedEmulation: emulation.totalFeeNanotons ?? 0
                )
            }
            try await pendingCoordinator.recordEmulation(emulation, for: identity)
            emulatedPending = TonPendingSignedIntent(
                identity: identity,
                intent: built.intent,
                message: built.message,
                walletState: built.walletState,
                feeQuote: feeQuote,
                emulation: emulation
            )
        } catch {
            // A valid bearer message was already exposed to the remote. Its absence at one
            // instant cannot prove it will not be broadcast later, so retain it and fail with
            // an explicitly ambiguous outcome unless reconciliation confirms execution.
            return try await reconcileOrThrowUnknown(
                TonPendingSignedIntent(
                    identity: identity,
                    intent: built.intent,
                    message: built.message,
                    walletState: built.walletState,
                    feeQuote: feeQuote,
                    emulation: nil
                )
            )
        }
        return try await broadcastAndReconcile(emulatedPending)
    }

    func acknowledgeConfirmedTransfer(
        senderAddress: String,
        identity: TonTransferIntentIdentity,
        messageHashHex: String
    ) async throws {
        guard let sender = try? TonSwift.Address.parse(senderAddress),
              sender.toRaw() == identity.sender,
              messageHashHex.utf8.count == 64,
              messageHashHex.utf8.allSatisfy({ byte in
                  (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
              })
        else {
            throw TonPendingIntentJournalError.corrupted
        }
        try await pendingCoordinator.acknowledgeConfirmed(
            senderRaw: identity.coordinationKey,
            identity: identity,
            messageHashHex: messageHashHex
        )
    }

    private func buildSignedTransfer(
        _ request: TonNativeSendRequest,
        identity: TonTransferIntentIdentity,
        feeQuote: TonTransferFeeQuote?
    ) async throws -> BuiltSignedTransfer {
        if let feeQuote {
            return try await buildQuoteBoundSignedTransfer(
                request,
                identity: identity,
                feeQuote: feeQuote
            )
        }

        let (now, validUntil) = try validatedTiming(for: request)
        let intent = try TonEmulationIntent(request: request)
        // Validate the mnemonic/key/sender binding locally before any remote call. Keep the
        // first derived private key scoped to this synchronous preflight instead of retaining
        // it across recipient/account network suspension points.
        do {
            try { () throws in
                let account = try TonKeyDerivation.signingAccount(for: request)
                _ = try TonTransferTransactionBuilder.buildAndSign(
                    request: transactionRequest(
                        from: request,
                        sequenceNumber: 0,
                        includeStateInit: false,
                        validUntil: validUntil
                    ),
                    privateKeySeed: account.privateKey,
                    now: now
                )
            }()
        } catch let error as TonTransferTransactionBuilderError {
            throw error
        } catch {
            throw TonSendServiceError.invalidAccount
        }

        try await inspectRecipients(request)
        let walletState = try await loadWalletState(senderAddress: request.senderAddress)
        let message: TonSignedExternalMessage
        do {
            // Re-derive only after all pre-signing network checks have completed so private
            // key material is live for the shortest practical synchronous signing window.
            let account = try TonKeyDerivation.signingAccount(for: request)
            message = try TonTransferTransactionBuilder.buildAndSign(
                request: transactionRequest(
                    from: request,
                    sequenceNumber: walletState.sequenceNumber,
                    includeStateInit: !walletState.isInitialized,
                    validUntil: validUntil
                ),
                privateKeySeed: account.privateKey,
                now: now
            )
        } catch let error as TonTransferTransactionBuilderError {
            throw error
        } catch {
            throw TonSendServiceError.invalidAccount
        }
        return BuiltSignedTransfer(
            identity: identity,
            intent: intent,
            message: message,
            walletState: walletState
        )
    }

    private func buildQuoteBoundSignedTransfer(
        _ request: TonNativeSendRequest,
        identity: TonTransferIntentIdentity,
        feeQuote: TonTransferFeeQuote
    ) async throws -> BuiltSignedTransfer {
        let now = clock()
        do {
            try feeQuote.validate(
                at: now,
                endpointOrigin: remote.reviewedSignedOperationOrigin
            )
        } catch TonTransferFeeQuoteError.invalidTiming {
            throw TonSendServiceError.feeQuoteExpired
        } catch {
            throw TonSendServiceError.feeQuoteMismatch
        }
        guard feeQuote.identity == identity,
              feeQuote.intent == (try TonEmulationIntent(request: request))
        else {
            throw TonSendServiceError.feeQuoteMismatch
        }

        // Validate key and sender ownership synchronously, then discard the first private-key
        // derivation before any suspension point.
        do {
            let account = try TonKeyDerivation.signingAccount(for: request)
            guard account.publicKey == feeQuote.publicKey,
                  try TonSwift.Address.parse(account.addressNonBounceable).toRaw() == identity.sender
            else {
                throw TonSendServiceError.invalidAccount
            }
        } catch let error as TonSendServiceError {
            throw error
        } catch {
            throw TonSendServiceError.invalidAccount
        }

        // Recheck mutable remote facts before signing. Any drift invalidates the visible quote.
        try await inspectRecipients(request)
        let walletState = try await loadWalletState(senderAddress: request.senderAddress)
        guard walletState == feeQuote.walletState else {
            throw TonSendServiceError.walletStateChangedSinceQuote
        }
        do {
            try feeQuote.validate(
                at: clock(),
                endpointOrigin: remote.reviewedSignedOperationOrigin
            )
        } catch TonTransferFeeQuoteError.invalidTiming {
            throw TonSendServiceError.feeQuoteExpired
        } catch {
            throw TonSendServiceError.feeQuoteMismatch
        }

        let rebuiltUnsigned = try TonTransferTransactionBuilder.buildForFeeEstimation(
            request: feeQuote.transactionRequest,
            publicKey: feeQuote.publicKey,
            now: feeQuote.templateCreatedAt
        )
        guard rebuiltUnsigned == feeQuote.unsignedMessage else {
            throw TonSendServiceError.feeQuoteMismatch
        }

        let signedMessage: TonSignedExternalMessage
        do {
            let account = try TonKeyDerivation.signingAccount(for: request)
            signedMessage = try TonTransferTransactionBuilder.buildAndSign(
                request: feeQuote.transactionRequest,
                privateKeySeed: account.privateKey,
                now: feeQuote.templateCreatedAt
            )
        } catch let error as TonTransferTransactionBuilderError {
            throw error
        } catch {
            throw TonSendServiceError.invalidAccount
        }
        guard signedMessage.publicKey == feeQuote.publicKey,
              signedMessage.signingPayloadHashHex == feeQuote.unsignedMessage.signingPayloadHashHex,
              signedMessage.walletAddress == feeQuote.unsignedMessage.walletAddress,
              signedMessage.sequenceNumber == feeQuote.unsignedMessage.sequenceNumber,
              signedMessage.validUntil == feeQuote.unsignedMessage.validUntil,
              signedMessage.includesStateInit == feeQuote.unsignedMessage.includesStateInit
        else {
            throw TonSendServiceError.feeQuoteMismatch
        }

        return BuiltSignedTransfer(
            identity: identity,
            intent: feeQuote.intent,
            message: signedMessage,
            walletState: walletState
        )
    }

    private func retry(_ pending: TonPendingSignedIntent) async throws -> TonSentTransferTransaction {
        var pending = pending
        do {
            if pending.confirmed {
                return try await confirmedResult(pending)
            }
            let wasConfirmed: Bool
            do {
                wasConfirmed = try await reconciled(pending)
            } catch {
                // A transport failure, timeout, or malformed/mismatched confirmation is
                // not proof of absence. Only explicit not-found responses may authorize
                // another submission of this bearer message.
                throw TonSendServiceError.broadcastOutcomeUnknown(
                    messageHashHex: pending.message.messageHashHex
                )
            }
            if wasConfirmed {
                return try await confirmedResult(pending)
            }
            guard clock() < pending.message.validUntil else {
                throw TonSendServiceError.broadcastOutcomeUnknown(
                    messageHashHex: pending.message.messageHashHex
                )
            }

            if pending.emulation == nil {
                let message = pending.message
                let intent = pending.intent
                let emulation: TonEmulationResult
                do {
                    emulation = try await withRemoteTimeout(error: .emulationTimedOut) {
                        try await self.remote.emulateSigned(
                            message: message,
                            intent: intent
                        )
                    }
                    try validateEmulation(emulation)
                    if let feeQuote = pending.feeQuote,
                       emulation.totalFeeNanotons != feeQuote.feeNanotons {
                        throw TonSendServiceError.feeChangedAfterConfirmation(
                            quoted: feeQuote.feeNanotons,
                            signedEmulation: emulation.totalFeeNanotons ?? 0
                        )
                    }
                } catch {
                    // This exact bearer BOC was already exposed during the first attempt.
                    // A retry-side emulation failure cannot make that exposure unambiguous.
                    throw TonSendServiceError.broadcastOutcomeUnknown(
                        messageHashHex: pending.message.messageHashHex
                    )
                }
                pending.emulation = emulation
                try await pendingCoordinator.recordEmulation(emulation, for: pending.identity)
            }
            return try await broadcastAndReconcile(pending)
        } catch {
            try? await pendingCoordinator.retainPending(pending)
            throw error
        }
    }

    private func requireStoredEndpointForRecovery(_ pending: TonPendingSignedIntent) async throws {
        guard let storedOrigin = pending.feeQuote?.endpointOrigin,
              let currentOrigin = remote.reviewedSignedOperationOrigin,
              storedOrigin == currentOrigin
        else {
            // `begin` moved this durable bearer to retrying. A temporary endpoint failure
            // must not strand that state or allow a new intent to replace the bearer.
            try? await pendingCoordinator.retainPending(pending)
            throw TonSendServiceError.broadcastOutcomeUnknown(
                messageHashHex: pending.message.messageHashHex
            )
        }
    }

    private func recoverPendingWithoutRebroadcast(
        _ pending: TonPendingSignedIntent
    ) async throws -> TonSentTransferTransaction {
        if pending.confirmed {
            return try await confirmedResult(pending)
        }
        do {
            if try await reconciled(pending) {
                return try await confirmedResult(pending)
            }
        } catch {
            // A transport failure or malformed response cannot authorize another bearer BOC.
        }
        try? await pendingCoordinator.retainPending(pending)
        throw TonSendServiceError.broadcastOutcomeUnknown(
            messageHashHex: pending.message.messageHashHex
        )
    }

    private func recoverDifferentPending(
        _ pending: TonPendingSignedIntent
    ) async throws -> TonSentTransferTransaction {
        // A prior outcome is surfaced and acknowledged before any different transfer may begin.
        // This prevents silently executing a second payment after recovery proves the first one.
        let confirmed = try await recoverPendingWithoutRebroadcast(pending)
        throw TonSendServiceError.priorIntentConfirmed(
            identity: pending.identity,
            messageHashHex: confirmed.messageHashHex
        )
    }

    private func broadcastAndReconcile(
        _ pending: TonPendingSignedIntent
    ) async throws -> TonSentTransferTransaction {
        guard clock() < pending.message.validUntil else {
            throw TonSendServiceError.broadcastOutcomeUnknown(
                messageHashHex: pending.message.messageHashHex
            )
        }
        do {
            try await withRemoteTimeout(error: .broadcastTimedOut) {
                try await self.remote.broadcast(message: pending.message)
            }
        } catch {
            // Network failure and timeout are ambiguous after bytes may have reached TonAPI.
        }
        return try await reconcileOrThrowUnknown(pending)
    }

    private func reconcileOrThrowUnknown(
        _ pending: TonPendingSignedIntent
    ) async throws -> TonSentTransferTransaction {
        if (try? await reconciled(pending)) == true {
            return try await confirmedResult(pending)
        }
        throw TonSendServiceError.broadcastOutcomeUnknown(
            messageHashHex: pending.message.messageHashHex
        )
    }

    private func reconciled(_ pending: TonPendingSignedIntent) async throws -> Bool {
        try await withRemoteTimeout(error: .reconciliationTimedOut) {
            for attempt in 0 ..< 3 {
                let result = try await self.remote.reconcile(
                    message: pending.message,
                    intent: pending.intent
                )
                if result == .confirmed {
                    return true
                }
                if attempt < 2 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            return false
        }
    }

    private func confirmedResult(
        _ pending: TonPendingSignedIntent
    ) async throws -> TonSentTransferTransaction {
        var pending = pending
        if pending.confirmed {
            // `begin` moves a persisted tombstone to retrying. Restore its stable pending
            // state before returning so an unacknowledged receipt remains recoverable again
            // in the same process as well as after restart.
            try await pendingCoordinator.retainPending(pending)
        } else {
            do {
                pending = try await pendingCoordinator.recordConfirmed(pending)
            } catch {
                try? await pendingCoordinator.retainPending(pending)
                throw TonSendServiceError.broadcastOutcomeUnknown(
                    messageHashHex: pending.message.messageHashHex
                )
            }
        }
        let emulation = pending.emulation ?? TonEmulationResult(
            accepted: false,
            totalFeeNanotons: nil
        )
        return TonSentTransferTransaction(
            prepared: TonPreparedTransferTransaction(
                signedMessage: pending.message,
                walletState: pending.walletState,
                emulation: emulation
            ),
            messageHashHex: pending.message.messageHashHex
        )
    }

    private func rejectMemoRequiredRecipient(_ recipientAddress: String) async throws {
        let memoRequired = try await withRemoteTimeout(error: .recipientInspectionTimedOut) {
            try await self.remote.recipientRequiresMemo(address: recipientAddress)
        }
        guard !memoRequired else {
            throw TonSendServiceError.recipientMemoRequired
        }
    }

    private func loadWalletState(senderAddress: String) async throws -> TonWalletRemoteState {
        let walletState = try await withRemoteTimeout(error: .walletStateTimedOut) {
            try await self.remote.walletState(address: senderAddress)
        }
        guard walletState.isInitialized || walletState.sequenceNumber == 0 else {
            throw TonSendServiceError.inconsistentWalletState
        }
        return walletState
    }

    private func validateEmulation(_ emulation: TonEmulationResult) throws {
        guard emulation.accepted else {
            throw TonSendServiceError.emulationRejected
        }
        guard let feeNanotons = emulation.totalFeeNanotons,
              feeNanotons > 0,
              feeNanotons <= maximumFeeNanotons
        else {
            throw TonSendServiceError.invalidEmulationFee
        }
    }

    private func validatedTiming(
        for request: TonNativeTransferDetails
    ) throws -> (now: UInt64, validUntil: UInt64) {
        try TonTransferTransactionBuilder.validateSupportedScope(asset: request.asset, network: request.network, jetton: request.jetton, tonConnect: request.tonConnect)
        _ = try TonEmulationIntent(request: request) // Includes the Int64 service cap.

        let now = clock()
        if let connect = request.tonConnect {
            guard connect.validUntil > now, connect.validUntil - now >= TonTransferTransactionBuilder.minimumLifetimeSeconds,
                  remoteTimeoutNanoseconds > 0, maximumFeeNanotons > 0 else { throw TonSendServiceError.feeQuoteExpired }
            return (now, connect.validUntil)
        }
        guard now <= UInt64(UInt32.max),
              messageLifetimeSeconds >= TonTransferTransactionBuilder.minimumLifetimeSeconds,
              messageLifetimeSeconds <= TonTransferTransactionBuilder.maximumLifetimeSeconds,
              remoteTimeoutNanoseconds > 0,
              maximumFeeNanotons > 0,
              now <= UInt64(UInt32.max) - messageLifetimeSeconds
        else {
            throw TonSendServiceError.invalidClock
        }
        return (now, now + messageLifetimeSeconds)
    }

    private func transactionRequest(
        from request: TonNativeTransferDetails,
        sequenceNumber: UInt64,
        includeStateInit: Bool,
        validUntil: UInt64
    ) -> TonTransferTransactionRequest {
        TonTransferTransactionRequest(
            asset: request.asset,
            network: request.network,
            senderAddress: request.senderAddress,
            recipientAddress: request.recipientAddress,
            amountNanotons: request.amountNanotons,
            sequenceNumber: sequenceNumber,
            includeStateInit: includeStateInit,
            validUntil: validUntil,
            bounce: request.bounce,
            comment: request.comment,
            jetton: request.jetton,
            tonConnect: request.tonConnect
        )
    }

    private func withRemoteTimeout<T: Sendable>(
        error timeoutError: TonSendServiceError,
        operation: @escaping @Sendable() async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        let state = TonRemoteRaceState<T>()

        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    guard state.install(continuation), !Task.isCancelled else {
                        state.resolve(.failure(CancellationError()))
                        return
                    }

                    let operationTask = Task {
                        guard state.claimOperationStart() else {
                            return
                        }
                        do {
                            state.resolve(.success(try await operation()))
                        } catch {
                            state.resolve(.failure(error))
                        }
                    }
                    let timeoutTask = Task {
                        do {
                            try await Task.sleep(nanoseconds: self.remoteTimeoutNanoseconds)
                            state.resolve(.failure(timeoutError))
                        } catch {
                            // Cancellation means another result already won the race.
                        }
                    }
                    state.registerTasks([operationTask, timeoutTask])
                }
            },
            onCancel: {
                state.resolve(.failure(CancellationError()))
            }
        )
    }
}

/// An unstructured first-result race is intentional here: structured task groups wait for
/// cancelled children before returning, so a transport that ignores cancellation could defeat
/// the deadline. This lock protects exactly-once continuation resumption and cancels the loser.
private final class TonRemoteRaceState<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var resolution: Result<Value, Error>?
    private var tasks: [Task<Void, Never>] = []
    private var operationStarted = false

    @discardableResult
    func install(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
        lock.lock()
        if let resolution {
            lock.unlock()
            continuation.resume(with: resolution)
            return false
        } else {
            self.continuation = continuation
            lock.unlock()
            return true
        }
    }

    func claimOperationStart() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard resolution == nil, !operationStarted else {
            return false
        }
        operationStarted = true
        return true
    }

    func registerTasks(_ tasks: [Task<Void, Never>]) {
        lock.lock()
        if resolution == nil {
            self.tasks = tasks
            lock.unlock()
        } else {
            lock.unlock()
            tasks.forEach { $0.cancel() }
        }
    }

    func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        guard resolution == nil else {
            lock.unlock()
            return
        }

        resolution = result
        let continuation = self.continuation
        self.continuation = nil
        let tasks = self.tasks
        self.tasks.removeAll()
        lock.unlock()

        tasks.forEach { $0.cancel() }
        continuation?.resume(with: result)
    }
}

enum TonTransferRemoteError: Error, Equatable {
    case invalidAccountAddress
    case invalidSequenceNumber
    case invalidFee
    case unsupportedAccountState
    case untrustedSignedOperationEndpoint
}

enum TonAccountSafetyPolicy {
    static func walletIsInitialized(
        status: String,
        isWallet: Bool,
        isScam: Bool?,
        isSuspended: Bool?,
        interfaces: [String]?
    ) throws -> Bool {
        guard isScam != true, isSuspended != true else {
            throw TonTransferRemoteError.unsupportedAccountState
        }
        switch status {
        case "active":
            guard isWallet, interfaces?.contains("wallet_v4r2") == true else {
                throw TonTransferRemoteError.unsupportedAccountState
            }
            return true
        case "nonexist", "uninit":
            return false
        default:
            throw TonTransferRemoteError.unsupportedAccountState
        }
    }

    static func recipientRequiresMemo(
        status: String,
        isScam: Bool?,
        isSuspended: Bool?,
        memoRequired: Bool?
    ) throws -> Bool {
        guard ["active", "nonexist", "uninit"].contains(status),
              isScam != true,
              isSuspended != true
        else {
            throw TonTransferRemoteError.unsupportedAccountState
        }
        return memoRequired == true
    }
}

enum TonEmulationPolicy {
    static func feeNanotons(
        _ value: Int64,
        maximum: UInt64 = TonSendService.defaultMaximumFeeNanotons
    ) throws -> UInt64 {
        guard value > 0, maximum > 0 else {
            throw TonTransferRemoteError.invalidFee
        }
        let fee = UInt64(value)
        guard fee <= maximum else {
            throw TonTransferRemoteError.invalidFee
        }
        return fee
    }

    static func acceptsExecution(
        transactionSucceeded: Bool,
        transactionAborted: Bool,
        transactionDestroyed: Bool,
        transactionTypeIsOrdinary: Bool,
        traceEmulated: Bool,
        traceHasWalletV4R2Interface: Bool,
        traceChildrenAreEmpty: Bool,
        transactionAccountMatches: Bool,
        computePhasePresent: Bool,
        computePhaseSkipped: Bool,
        computePhaseSucceeded: Bool,
        computeExitCodeZero: Bool,
        actionPhasePresent: Bool,
        actionPhaseSucceeded: Bool,
        actionCountIsOne: Bool,
        skippedActionCountIsZero: Bool,
        outMessageCountIsOne: Bool,
        inboundMessageMatches: Bool,
        outboundMessageMatches: Bool
    ) -> Bool {
        transactionSucceeded &&
            !transactionAborted &&
            !transactionDestroyed &&
            transactionTypeIsOrdinary &&
            traceEmulated &&
            traceHasWalletV4R2Interface &&
            traceChildrenAreEmpty &&
            transactionAccountMatches &&
            computePhasePresent &&
            !computePhaseSkipped &&
            computePhaseSucceeded &&
            computeExitCodeZero &&
            actionPhasePresent &&
            actionPhaseSucceeded &&
            actionCountIsOne &&
            skippedActionCountIsZero &&
            outMessageCountIsOne &&
            inboundMessageMatches &&
            outboundMessageMatches
    }

    static func acceptsRisk(
        eventIsScam: Bool,
        eventInProgress: Bool,
        transfersAllRemainingBalance: Bool,
        tonRiskWithinIntent: Bool,
        hasJettonRisk: Bool,
        hasNFTRisk: Bool
    ) -> Bool {
        !eventIsScam &&
            !eventInProgress &&
            !transfersAllRemainingBalance &&
            tonRiskWithinIntent &&
            !hasJettonRisk &&
            !hasNFTRisk
    }
}

/// Production TON API adapter. A successful emulation must execute cleanly and must not
/// introduce transfer-all, Jetton, or NFT risk beyond the signed native TON message.
final class TonAPIRemoteClient: TonTransferRemoteProtocol, @unchecked Sendable {
    private let client: any APIProtocol
    private let signedOperationsAllowed: Bool
    private let signedOperationOrigin: String?

    var reviewedSignedOperationOrigin: String? {
        signedOperationOrigin
    }

    init(client: any APIProtocol) {
        self.client = client
        signedOperationsAllowed = false
        signedOperationOrigin = nil
    }

    private init(
        client: any APIProtocol,
        signedOperationsAllowed: Bool,
        signedOperationOrigin: String?
    ) {
        self.client = client
        self.signedOperationsAllowed = signedOperationsAllowed
        self.signedOperationOrigin = signedOperationOrigin
    }

    #if DEBUG
        init(trustedTestClient client: any APIProtocol) {
            self.client = client
            signedOperationsAllowed = true
            signedOperationOrigin = TonAPIClientFactory.canonicalAuthenticatedOrigin.absoluteString
        }
    #endif

    convenience init(
        factory: TonAPIClientFactory,
        configuration: URLSessionConfiguration? = nil
    ) {
        let isReviewedOrigin = TonAPIClientFactory.isReviewedProductionSendServerURL(factory.serverURL) &&
            factory.hasReviewedProductionSendCredential
        self.init(
            client: factory.tonAPIClient(configuration: configuration),
            signedOperationsAllowed: isReviewedOrigin,
            signedOperationOrigin: isReviewedOrigin ? factory.serverURL.absoluteString : nil
        )
    }

    func jettonWallet(ownerAddress: String, assetAddress: String, amount: String, precision: Int) async throws -> TonResolvedJettonWallet {
        try requireTrustedSignedOperationEndpoint()
        let requested = try TonTransferTransactionBuilder.parseAmount(amount)
        let owner = try TonTransferTransactionBuilder.canonicalMainnetAddress(ownerAddress, basechainOnly: true)
        let selected = try TonTransferTransactionBuilder.canonicalMainnetAddress(assetAddress, basechainOnly: true)
        let balances = try await client.getAccountJettonsBalances(.init(path: .init(account_id: owner))).ok.body.json.balances
        let matching = balances.filter { balance in
            addressesMatch(balance.jetton.address, selected) || addressesMatch(balance.wallet_address.address, selected)
        }
        guard matching.count == 1, let balance = matching.first,
              !balance.wallet_address.is_scam, balance.jetton.decimals == precision,
              let available = BigUInt(balance.balance), requested <= available,
              balance.lock == nil || balance.lock?.amount == "0"
        else { throw TonTransferTransactionBuilderError.unsupportedAsset }
        let master = try TonTransferTransactionBuilder.canonicalMainnetAddress(balance.jetton.address, basechainOnly: true)
        let wallet = try TonTransferTransactionBuilder.canonicalMainnetAddress(balance.wallet_address.address, basechainOnly: true)
        guard master != wallet, owner != wallet else { throw TonTransferTransactionBuilderError.unsupportedAsset }
        return TonResolvedJettonWallet(masterAddress: master, walletAddress: wallet)
    }

    func walletState(address: String) async throws -> TonWalletRemoteState {
        async let accountOutput = client.getAccount(
            .init(path: .init(account_id: address))
        )
        async let sequenceOutput = client.getAccountSeqno(
            .init(path: .init(account_id: address))
        )

        let account = try await accountOutput.ok.body.json
        let sequenceNumber = try await sequenceOutput.ok.body.json.seqno
        guard sequenceNumber >= 0 else {
            throw TonTransferRemoteError.invalidSequenceNumber
        }

        do {
            guard try TonSwift.Address.parse(account.address) == TonSwift.Address.parse(address) else {
                throw TonTransferRemoteError.invalidAccountAddress
            }
        } catch let error as TonTransferRemoteError {
            throw error
        } catch {
            throw TonTransferRemoteError.invalidAccountAddress
        }

        let isInitialized = try TonAccountSafetyPolicy.walletIsInitialized(
            status: account.status,
            isWallet: account.is_wallet,
            isScam: account.is_scam,
            isSuspended: account.is_suspended,
            interfaces: account.interfaces
        )

        return TonWalletRemoteState(
            sequenceNumber: UInt64(sequenceNumber),
            isInitialized: isInitialized
        )
    }

    func recipientRequiresMemo(address: String) async throws -> Bool {
        let account = try await client.getAccount(
            .init(path: .init(account_id: address))
        ).ok.body.json
        guard addressesMatch(account.address, address) else {
            throw TonTransferRemoteError.invalidAccountAddress
        }
        return try TonAccountSafetyPolicy.recipientRequiresMemo(
            status: account.status,
            isScam: account.is_scam,
            isSuspended: account.is_suspended,
            memoRequired: account.memo_required
        )
    }

    func emulateUnsigned(
        message: TonUnsignedEmulationMessage,
        intent: TonEmulationIntent
    ) async throws -> TonEmulationResult {
        let output = try await client.emulateMessageToTrace(
            .init(
                query: .init(ignore_signature_check: true),
                body: .json(.init(boc: message.bocBase64))
            )
        )
        let trace = try output.ok.body.json
        let feeNanotons = try TonEmulationPolicy.feeNanotons(trace.transaction.total_fees)
        let effects = intent.tonConnect == nil ? nil : try await tonConnectEffects(bocBase64: message.bocBase64, unsigned: true)
        return TonEmulationResult(
            accepted: executionAccepted(
                trace: trace,
                intent: intent,
                externalMessageBoc: message.boc
            ),
            totalFeeNanotons: feeNanotons,
            executionEffects: effects
        )
    }

    func emulateSigned(
        message: TonSignedExternalMessage,
        intent: TonEmulationIntent
    ) async throws -> TonEmulationResult {
        try requireTrustedSignedOperationEndpoint()
        try requireReviewedNetwork(intent)
        let output = try await client.emulateMessageToWallet(
            .init(
                body: .json(
                    .init(boc: message.bocBase64)
                )
            )
        )
        let consequences = try output.ok.body.json
        let transaction = consequences.trace.transaction
        let risk = consequences.risk
        let feeNanotons = try TonEmulationPolicy.feeNanotons(transaction.total_fees)
        if intent.tonConnect != nil {
            let effects = try await tonConnectEffects(bocBase64: message.bocBase64, unsigned: false)
            let accepted = executionAccepted(trace: consequences.trace, intent: intent, externalMessageBoc: message.boc) &&
                !consequences.event.is_scam && !consequences.event.in_progress &&
                addressesMatch(consequences.event.account.address, intent.senderAddress) &&
                tonConnectRiskMatches(risk, effects: effects, intent: intent)
            return TonEmulationResult(accepted: accepted, totalFeeNanotons: feeNanotons, executionEffects: effects)
        }
        let accepted = executionAccepted(
            trace: consequences.trace,
            intent: intent,
            externalMessageBoc: message.boc
        ) && TonEmulationPolicy.acceptsRisk(
            eventIsScam: consequences.event.is_scam,
            eventInProgress: consequences.event.in_progress,
            transfersAllRemainingBalance: risk.transfer_all_remaining_balance,
            tonRiskWithinIntent: risk.ton >= 0 && risk.ton <= intent.amountNanotons,
            hasJettonRisk: !jettonRiskMatches(risk.jettons, intent: intent),
            hasNFTRisk: !risk.nfts.isEmpty
        ) && addressesMatch(consequences.event.account.address, intent.senderAddress) &&
            jettonEventMatches(consequences.event, intent: intent)

        return TonEmulationResult(
            accepted: accepted,
            totalFeeNanotons: feeNanotons
        )
    }

    func broadcast(message: TonSignedExternalMessage) async throws {
        try requireTrustedSignedOperationEndpoint()
        let output = try await client.sendBlockchainMessage(
            .init(
                body: .json(
                    .init(boc: message.bocBase64)
                )
            )
        )
        _ = try output.ok
    }

    func reconcile(
        message: TonSignedExternalMessage,
        intent: TonEmulationIntent
    ) async throws -> TonReconciliationResult {
        try requireTrustedSignedOperationEndpoint()
        try requireReviewedNetwork(intent)
        let output = try await client.getBlockchainTransactionByMessageHash(
            .init(path: .init(msg_id: message.messageHashHex))
        )
        switch output {
        case let .ok(ok):
            let transaction = try ok.body.json
            guard transactionAccepted(
                transaction,
                intent: intent,
                externalMessageBoc: message.boc
            ) else {
                throw TonTransferRemoteError.unsupportedAccountState
            }
            return .confirmed
        case let .default(statusCode, _):
            guard statusCode == 404 else {
                throw TonTransferRemoteError.unsupportedAccountState
            }
            return .notFound
        }
    }

    private func requireReviewedNetwork(_ intent: TonEmulationIntent) throws {
        guard let origin = signedOperationOrigin, let url = URL(string: origin),
              TonAPIClientFactory.reviewedSendNetwork(for: url) == (intent.tonConnect?.network ?? .mainnet) else {
            throw TonTransferRemoteError.untrustedSignedOperationEndpoint
        }
    }

    private func requireTrustedSignedOperationEndpoint() throws {
        guard signedOperationsAllowed else {
            throw TonTransferRemoteError.untrustedSignedOperationEndpoint
        }
    }

    private func executionAccepted(
        trace: Components.Schemas.Trace,
        intent: TonEmulationIntent,
        externalMessageBoc: Data
    ) -> Bool {
        if intent.tonConnect != nil {
            return trace.emulated == true && trace.interfaces.contains("wallet_v4r2") &&
                linkedChildrenAccepted(trace, intent: intent) &&
                transactionAccepted(trace.transaction, intent: intent, externalMessageBoc: externalMessageBoc)
        }
        let transaction = trace.transaction
        let computePhase = transaction.compute_phase
        let actionPhase = transaction.action_phase
        let accepted = TonEmulationPolicy.acceptsExecution(
            transactionSucceeded: transaction.success,
            transactionAborted: transaction.aborted,
            transactionDestroyed: transaction.destroyed,
            transactionTypeIsOrdinary: transaction.transaction_type == .TransOrd,
            traceEmulated: trace.emulated == true,
            traceHasWalletV4R2Interface: trace.interfaces.contains("wallet_v4r2"),
            // TonAPI omits `children` when empty in some valid responses.
            traceChildrenAreEmpty: linkedChildrenAccepted(trace, intent: intent),
            transactionAccountMatches: addressesMatch(
                transaction.account.address,
                intent.senderAddress
            ) && transaction.account.is_wallet && !transaction.account.is_scam,
            computePhasePresent: computePhase != nil,
            computePhaseSkipped: computePhase?.skipped ?? true,
            computePhaseSucceeded: computePhase?.success == true,
            computeExitCodeZero: computePhase?.exit_code == 0,
            actionPhasePresent: actionPhase != nil,
            actionPhaseSucceeded: actionPhase?.success == true,
            actionCountIsOne: actionPhase?.total_actions == 1,
            skippedActionCountIsZero: actionPhase?.skipped_actions == 0,
            outMessageCountIsOne: transaction.out_msgs.count == 1,
            inboundMessageMatches: inboundMessageMatches(
                transaction.in_msg,
                senderAddress: intent.senderAddress,
                externalMessageBoc: externalMessageBoc
            ),
            outboundMessageMatches: outboundMessageMatches(
                transaction.out_msgs.first,
                intent: intent
            )
        )
        return accepted
    }

    private func jettonRiskMatches(_ risks: [Components.Schemas.JettonQuantity], intent: TonEmulationIntent) -> Bool {
        guard let jetton = intent.jetton else { return risks.isEmpty }
        guard risks.count == 1, let risk = risks.first else { return false }
        return risk.quantity == jetton.amount && !risk.wallet_address.is_scam &&
            addressesMatch(risk.wallet_address.address, intent.recipientAddress) &&
            addressesMatch(risk.jetton.address, jetton.masterAddress)
    }

    private func jettonEventMatches(_ event: Components.Schemas.AccountEvent, intent: TonEmulationIntent) -> Bool {
        guard let jetton = intent.jetton else { return true }
        let transfers = event.actions.filter { $0.JettonTransfer != nil }
        guard transfers.count == 1, let action = transfers.first, action.status == .ok,
              let transfer = action.JettonTransfer else { return false }
        return transfer.amount == jetton.amount && transfer.refund == nil && transfer.encrypted_comment == nil &&
            transfer.sender?.is_scam == false && transfer.recipient?.is_scam == false &&
            addressesMatch(transfer.sender?.address, intent.senderAddress) &&
            addressesMatch(transfer.recipient?.address, jetton.recipientAddress) &&
            addressesMatch(transfer.senders_wallet, intent.recipientAddress) &&
            addressesMatch(transfer.jetton.address, jetton.masterAddress)
    }

    /// Delivered native transfers and TEP-74 transfers have child transactions. Bind
    /// every returned child to one unique internal message of its parent, with bounded
    /// depth/size. A token notification to an uninitialized owner may skip computation;
    /// token delivery itself must still appear as the exact successful Jetton event.
    private func linkedChildrenAccepted(_ trace: Components.Schemas.Trace, intent: TonEmulationIntent) -> Bool {
        if intent.jetton != nil, trace.children?.isEmpty != false { return false }
        var count = 0
        func visit(_ parent: Components.Schemas.Trace, depth: Int) -> Bool {
            let children = parent.children ?? []
            guard depth <= 8, children.count <= 16 else { return false }
            var consumed = Set<Int>()
            for child in children {
                count += 1
                let transaction = child.transaction
                guard count <= 32, child.emulated == true, !transaction.destroyed,
                      transaction.transaction_type == .TransOrd, !transaction.account.is_scam,
                      let inbound = transaction.in_msg, inbound.msg_type == .int_msg,
                      inbound.value >= 0, inbound.destination?.is_scam == false,
                      addressesMatch(inbound.destination?.address, transaction.account.address),
                      let index = parent.transaction.out_msgs.indices.first(where: { index in
                          let outbound = parent.transaction.out_msgs[index]
                          return !consumed.contains(index) && outbound.msg_type == .int_msg &&
                              outbound.created_lt == inbound.created_lt && outbound.value == inbound.value &&
                              outbound.bounce == inbound.bounce && outbound.bounced == inbound.bounced &&
                              outbound.raw_body?.lowercased() == inbound.raw_body?.lowercased() &&
                              outbound._init == inbound._init &&
                              addressesMatch(outbound.source?.address, parent.transaction.account.address) &&
                              addressesMatch(inbound.source?.address, parent.transaction.account.address) &&
                              addressesMatch(outbound.destination?.address, transaction.account.address)
                      }) else { return false }
                consumed.insert(index)
                let target = intent.jetton?.recipientAddress ?? intent.recipientAddress
                let value = intent.jetton == nil ? intent.amountNanotons : 1
                let connectReceipt = intent.tonConnect?.messages.contains { message in
                    !message.bounce && Int64(message.amountNanotons) == inbound.value &&
                        addressesMatch(message.recipientAddress, transaction.account.address)
                } == true
                let uninitializedReceipt = transaction.compute_phase?.skipped == true &&
                    !inbound.bounce && !inbound.bounced &&
                    ((inbound.value == value && addressesMatch(transaction.account.address, target)) || connectReceipt) && transaction.out_msgs.isEmpty &&
                    child.children?.isEmpty != false
                guard (transaction.success && !transaction.aborted) || uninitializedReceipt,
                      visit(child, depth: depth + 1) else { return false }
            }
            return true
        }
        return visit(trace, depth: 0)
    }

    private func transactionAccepted(
        _ transaction: Components.Schemas.Transaction,
        intent: TonEmulationIntent,
        externalMessageBoc: Data
    ) -> Bool {
        let computePhase = transaction.compute_phase
        let actionPhase = transaction.action_phase
        return transaction.success &&
            !transaction.aborted &&
            !transaction.destroyed &&
            transaction.transaction_type == .TransOrd &&
            addressesMatch(transaction.account.address, intent.senderAddress) &&
            transaction.account.is_wallet &&
            !transaction.account.is_scam &&
            computePhase != nil &&
            computePhase?.skipped == false &&
            computePhase?.success == true &&
            computePhase?.exit_code == 0 &&
            actionPhase?.success == true &&
            actionPhase?.total_actions == Int32(intent.tonConnect?.messages.count ?? 1) &&
            actionPhase?.skipped_actions == 0 &&
            transaction.out_msgs.count == (intent.tonConnect?.messages.count ?? 1) &&
            inboundMessageMatches(
                transaction.in_msg,
                senderAddress: intent.senderAddress,
                externalMessageBoc: externalMessageBoc
            ) &&
            outboundMessagesMatch(transaction.out_msgs, intent: intent)
    }

    private func inboundMessageMatches(
        _ message: Components.Schemas.Message?,
        senderAddress: String,
        externalMessageBoc: Data
    ) -> Bool {
        guard let message,
              message.msg_type == .ext_in_msg,
              message.source == nil,
              message.destination?.is_scam == false,
              addressesMatch(message.destination?.address, senderAddress),
              let expectedBodyHash = externalMessageBodyHashHex(externalMessageBoc)
        else {
            return false
        }
        return rawBodyMatches(message.raw_body, expectedHashHex: expectedBodyHash)
    }

    private func outboundMessageMatches(
        _ message: Components.Schemas.Message?,
        intent: TonEmulationIntent
    ) -> Bool {
        guard let message,
              message.msg_type == .int_msg,
              message.ihr_disabled,
              message.bounce == intent.bounce,
              !message.bounced,
              message.value == intent.amountNanotons,
              message.ihr_fee >= 0,
              message.fwd_fee >= 0,
              message.source?.is_scam == false,
              message.destination?.is_scam == false,
              addressesMatch(message.source?.address, intent.senderAddress),
              addressesMatch(message.destination?.address, intent.recipientAddress)
        else {
            return false
        }
        return rawBodyMatches(
            message.raw_body,
            expectedHashHex: intent.messageBodyHashHex
        )
    }

    private func externalMessageBodyHashHex(_ boc: Data) -> String? {
        guard let root = try? TonTransferTransactionBuilder.parseBoundedBoc(boc, maximumBytes: TonTransferTransactionBuilder.maximumTonConnectBocBytes),
              let message = try? Message.loadFrom(slice: root.beginParse())
        else {
            return nil
        }
        return message.body.hash().hexString()
    }

    private func rawBodyMatches(_ rawBody: String?, expectedHashHex: String) -> Bool {
        guard let rawBody,
              !rawBody.isEmpty,
              rawBody.count.isMultiple(of: 2),
              !rawBody.hasPrefix("0x"),
              rawBody.unicodeScalars.allSatisfy(Self.isHexScalar),
              let data = Data(hex: rawBody),
              let root = try? TonTransferTransactionBuilder.parseBoundedBoc(data, maximumBytes: TonTransferTransactionBuilder.maximumTonConnectBocBytes)
        else {
            return false
        }
        return root.hash().hexString().lowercased() == expectedHashHex.lowercased()
    }

    private static func isHexScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48 ... 57, 65 ... 70, 97 ... 102:
            return true
        default:
            return false
        }
    }

    private func addressesMatch(_ actual: String?, _ expected: String) -> Bool {
        guard let actual,
              let actualAddress = try? TonSwift.Address.parse(actual),
              let expectedAddress = try? TonSwift.Address.parse(expected)
        else {
            return false
        }
        return actualAddress == expectedAddress
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}

extension TonConnectTransferRequest {
    var estimateRequest: TonNativeEstimateRequest {
        TonNativeEstimateRequest(
            asset: .tonConnect,
            network: network,
            publicKey: publicKey,
            senderAddress: senderAddress,
            recipientAddress: messages[0].recipientAddress,
            amountNanotons: amountNanotons,
            bounce: messages[0].bounce,
            tonConnect: self
        )
    }
}

extension TonSendService {
    func quoteTonConnect(_ request: TonConnectTransferRequest) async throws -> TonTransferFeeQuote {
        _ = try TonConnectTransferRequest.decodeCanonical(request.canonicalData())
        return try await quote(request.estimateRequest)
    }

    func sendTonConnect(
        _ request: TonConnectTransferRequest, feeQuote: TonTransferFeeQuote?, legacyAccount: LegacyTonAccount,
        signingCredentials: @escaping () throws -> TonSigningCredentials
    ) async throws -> TonSentTransferTransaction {
        _ = try TonConnectTransferRequest.decodeCanonical(request.canonicalData())
        try requireNetworkOrigin(request.network)
        return try await send(
            request.estimateRequest,
            feeQuote: feeQuote,
            legacyAccount: legacyAccount,
            signingCredentials: signingCredentials
        )
    }

    /// The bridge persists its exact reply before acknowledgement. Retrying this after
    /// a crash must succeed even if the previous acknowledgement already removed the bearer.
    func acknowledgeTonConnect(request: TonConnectTransferRequest, messageHashHex: String) async throws {
        let identity = try TonTransferIntentIdentity(request: request.estimateRequest)
        guard let pending = try await pendingCoordinator.pending(senderRaw: identity.coordinationKey) else { return }
        // A newer identity can own this nonce slot only after the prior bearer was
        // acknowledged. A cached bridge reply must not disturb that newer request.
        guard pending.identity == identity else { return }
        try await pendingCoordinator.acknowledgeConfirmed(
            senderRaw: identity.coordinationKey,
            identity: identity,
            messageHashHex: messageHashHex
        )
    }

    private func requireNetworkOrigin(_ network: TonTransferNetwork) throws {
        guard let origin = remote.reviewedSignedOperationOrigin,
              let url = URL(string: origin), TonAPIClientFactory.reviewedSendNetwork(for: url) == network else {
            throw TonSendServiceError.untrustedFeeQuoteEndpoint
        }
    }

    private func inspectRecipients(_ request: TonNativeTransferDetails) async throws {
        if let connect = request.tonConnect {
            for message in connect.messages where message.payloadBocBase64 == nil && message.stateInitBocBase64 == nil {
                try await rejectMemoRequiredRecipient(message.recipientAddress)
            }
        } else { try await rejectMemoRequiredRecipient(request.jetton?.recipientAddress ?? request.recipientAddress) }
    }
}

/// Exact predicted actions are retained with the visible quote. Hashes, timestamps and
/// transaction IDs of the enclosing event are excluded because signed emulation changes them.
struct TonConnectExecutionEffects: Equatable, Sendable {
    let actionsData: Data

    init(actionsData: Data) throws {
        guard !actionsData.isEmpty, actionsData.count <= 128 * 1024 else { throw TonSendServiceError.emulationRejected }
        let actions = try JSONDecoder().decode([Components.Schemas.Action].self, from: actionsData)
        guard (1 ... 64).contains(actions.count), actions.allSatisfy({ action in
            guard action.status == .ok, action.simple_preview.accounts.allSatisfy({ !$0.is_scam }),
                  let encoded = try? JSONEncoder().encode(action),
                  let object = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return false }
            return object.keys.filter { $0 != "status" && $0 != "simple_preview" }.count == 1
        }) else { throw TonSendServiceError.emulationRejected }
        self.actionsData = actionsData
    }

    init(actions: [Components.Schemas.Action]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try self.init(actionsData: encoder.encode(actions))
    }

    var descriptions: [String] {
        guard let actions = try? JSONDecoder().decode([Components.Schemas.Action].self, from: actionsData) else { return [] }
        return actions.map { action in
            let preview = action.simple_preview
            return [preview.name, preview.value, preview.description].compactMap { $0 }.joined(separator: " · ")
        }
    }
}

extension TonAPIRemoteClient {
    private func tonConnectEffects(bocBase64: String, unsigned: Bool) async throws -> TonConnectExecutionEffects {
        let output = try await client.emulateMessageToEvent(.init(
            query: .init(ignore_signature_check: unsigned),
            headers: .init(Accept_hyphen_Language: "en"),
            body: .json(.init(boc: bocBase64))
        ))
        let event = try output.ok.body.json
        guard !event.is_scam, !event.in_progress else { throw TonSendServiceError.emulationRejected }
        return try TonConnectExecutionEffects(actions: event.actions)
    }

    private func outboundMessagesMatch(_ messages: [Components.Schemas.Message], intent: TonEmulationIntent) -> Bool {
        guard let connect = intent.tonConnect else {
            return messages.count == 1 && outboundMessageMatches(messages.first, intent: intent)
        }
        guard messages.count == connect.messages.count else { return false }
        return zip(messages, connect.messages).allSatisfy { actual, expected in
            guard actual.msg_type == .int_msg, actual.ihr_disabled, !actual.bounced,
                  actual.bounce == expected.bounce, actual.value == Int64(expected.amountNanotons),
                  actual.ihr_fee >= 0, actual.fwd_fee >= 0,
                  actual.source?.is_scam == false, actual.destination?.is_scam == false,
                  addressesMatch(actual.source?.address, connect.senderAddress),
                  addressesMatch(actual.destination?.address, expected.recipientAddress),
                  let bodyHash = try? expected.payloadBocBase64.map({ try TonTransferTransactionBuilder.tonConnectBoc($0).hash }) ?? TonTransferTransactionBuilder.messageBodyHashHex(comment: nil),
                  rawBodyMatches(actual.raw_body, expectedHashHex: bodyHash) else { return false }
            if let stateHash = expected.stateInitHashHex {
                guard let actualState = actual._init?.boc else { return false }
                let candidates = [Data(base64Encoded: actualState), Data(hex: actualState)].compactMap { $0 }
                guard candidates.contains(where: { bytes in
                    guard let root = try? TonTransferTransactionBuilder.parseBoundedBoc(bytes, maximumBytes: TonTransferTransactionBuilder.maximumTonConnectBocBytes) else { return false }
                    return root.hash().hexString().lowercased() == stateHash
                }) else { return false }
            } else if actual._init != nil { return false }
            return true
        }
    }

    /// Every additional asset debit reported by signed emulation must appear as a
    /// successful action in the immutable effects reviewed on the previous screen.
    private func tonConnectRiskMatches(_ risk: Components.Schemas.Risk, effects: TonConnectExecutionEffects, intent: TonEmulationIntent) -> Bool {
        guard !risk.transfer_all_remaining_balance, risk.ton >= 0, risk.ton <= intent.amountNanotons,
              let actions = try? JSONDecoder().decode([Components.Schemas.Action].self, from: effects.actionsData) else { return false }
        var jettonAmounts: [String: BigUInt] = [:]
        var nftAddresses = Set<String>()
        for action in actions {
            if let transfer = action.JettonTransfer, addressesMatch(transfer.sender?.address, intent.senderAddress),
               let amount = BigUInt(transfer.amount), let master = try? TonSwift.Address.parse(transfer.jetton.address).toRaw() {
                jettonAmounts[master, default: BigUInt(0)] += amount
            }
            if let burn = action.JettonBurn, addressesMatch(burn.sender.address, intent.senderAddress),
               let amount = BigUInt(burn.amount), let master = try? TonSwift.Address.parse(burn.jetton.address).toRaw() {
                jettonAmounts[master, default: BigUInt(0)] += amount
            }
            if let swap = action.JettonSwap, addressesMatch(swap.user_wallet.address, intent.senderAddress),
               let amount = BigUInt(swap.amount_in), let masterValue = swap.jetton_master_in?.address,
               let master = try? TonSwift.Address.parse(masterValue).toRaw() {
                jettonAmounts[master, default: BigUInt(0)] += amount
            }
            if let transfer = action.NftItemTransfer, addressesMatch(transfer.sender?.address, intent.senderAddress),
               let address = try? TonSwift.Address.parse(transfer.nft).toRaw() { nftAddresses.insert(address) }
        }
        var debits: [String: BigUInt] = [:]
        for item in risk.jettons {
            guard !item.wallet_address.is_scam, let amount = BigUInt(item.quantity),
                  let master = try? TonSwift.Address.parse(item.jetton.address).toRaw() else { return false }
            debits[master, default: BigUInt(0)] += amount
        }
        guard debits.allSatisfy({ master, amount in amount <= jettonAmounts[master, default: BigUInt(0)] }) else { return false }
        return risk.nfts.allSatisfy { item in
            guard let raw = try? TonSwift.Address.parse(item.address).toRaw() else { return false }
            return nftAddresses.contains(raw)
        }
    }
}
