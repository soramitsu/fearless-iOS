import Foundation
import SoraFoundation
import Combine
import WalletConnectSign
import WalletConnectRelay
import ReownWalletKit

/// WalletConnect signing stays off until its confirmation meets the wallet's signing
/// rules: it shows what is actually signed (network, recipient, amount and fee), the
/// request is bound to an account the session approved, signing asks for the PIN or
/// biometrics, and messages use the standard `<Bytes>` envelope. Until then every
/// dApp request is declined before any key is read and the user is told that nothing
/// was signed; sessions stay listed and can be disconnected. Like IrohaConnect, there
/// is intentionally no environment-variable, remote-config, or runtime-toggle override.
struct WalletConnectSigningPolicy: Equatable {
    let isEnabled: Bool

    private init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    static let production = WalletConnectSigningPolicy(isEnabled: false)
    #if DEBUG
        static let enabledForTests = WalletConnectSigningPolicy(isEnabled: true)
    #endif
}

enum WalletConnectSigningError: Error {
    case unavailable
}

protocol WalletConnectService: ApplicationServiceProtocol {
    func set(listener: WalletConnectServiceDelegate)
    func connect(uri: String) async throws
    func disconnect(topic: String) async throws
    func getSessions() -> [Session]
    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession]

    func submit(proposalDecision: WalletConnectProposalDecision) async throws
    func submit(signDecision: WalletConnectSignDecision) async throws
}

protocol WalletConnectServiceDelegate: AnyObject {
    func session(proposal: Session.Proposal)
    func sign(request: Request, session: Session?)
    /// A dApp asked for a signature while signing is unavailable. The request was
    /// already declined; nothing was signed.
    func signingUnavailable(request: Request, session: Session?)
    func didChange(sessions: [Session])
}

extension WalletConnectServiceDelegate {
    func session(proposal _: Session.Proposal) {}
    func sign(request _: Request, session _: Session?) {}
    func signingUnavailable(request _: Request, session _: Session?) {}
    func didChange(sessions _: [Session]) {}
}

enum WalletConnectGroupIdentifierResolver {
    static let productionBundleIdentifier = "jp.co.soramitsu.fearlesswallet"
    static let developmentBundleIdentifier = "jp.co.soramitsu.fearlesswallet.dev"
    static let productionGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet"
    static let developmentGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet.walletconnect"

    static func resolve(bundleIdentifier: String?) -> String? {
        if bundleIdentifier == productionBundleIdentifier {
            return productionGroupIdentifier
        }

        if bundleIdentifier == developmentBundleIdentifier {
            return developmentGroupIdentifier
        }

        return nil
    }
}

final class WalletConnectServiceImpl: WalletConnectService {
    static let shared = WalletConnectServiceImpl()

    private let socketFactory: WebSocketFactory
    private let signingPolicy: WalletConnectSigningPolicy
    private let respond: (Request, RPCResult) async throws -> Void
    private var listeners: [WeakWrapper] = []
    private var cancellablesBag = Set<AnyCancellable>()
    private var legacyStorageMigrator: WalletConnectLegacyStorageMigrator?

    init(
        socketFactory: WebSocketFactory = WalletConnectSocketFactory(),
        signingPolicy: WalletConnectSigningPolicy = .production,
        respond: @escaping (Request, RPCResult) async throws -> Void = { request, response in
            try await WalletKit.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: response
            )
        }
    ) {
        self.socketFactory = socketFactory
        self.signingPolicy = signingPolicy
        self.respond = respond
    }

    // MARK: - ApplicationServiceProtocol

    func setup() {
        guard
            let groupIdentifier = WalletConnectGroupIdentifierResolver.resolve(
                bundleIdentifier: Bundle.main.bundleIdentifier
            )
        else {
            Logger.shared.error(
                "WalletConnect setup skipped for an unsupported application identity"
            )
            return
        }

        // The SDK moves storage left outside the app group by earlier releases into the group once its stores
        // are created below; remember the legacy sessions before that happens.
        let legacyStorageMigrator = WalletConnectLegacyStorageMigrator(groupIdentifier: groupIdentifier)
        legacyStorageMigrator.recordLegacySessionsIfNeeded()
        self.legacyStorageMigrator = legacyStorageMigrator

        #if canImport(FearlessKeys)
            #if F_DEV
                let projectId = WalletConnectDebug.projectId
            #else
                let projectId = WalletConnect.projectId
            #endif
        #else
            let projectId = WalletConnect.projectId
        #endif
        Networking.configure(
            groupIdentifier: groupIdentifier,
            projectId: projectId,
            socketFactory: socketFactory
        )
        // Reown reports SDK traces and errors to its own telemetry service by
        // default. The wallet sends no analytics, so it is switched off.
        Events.instance.setTelemetryEnabled(false)
        WalletKit.configure(
            metadata: AppMetadata.createFearlessMetadata(),
            crypto: DefaultCryptoProvider()
        )
        setupSubscription()
        legacyStorageMigrator.logContinuity(activeTopics: Set(getSessions().map(\.topic)))
    }

    func throttle() {
        try? Networking.instance.disconnect(closeCode: .normalClosure)

        cancellablesBag.forEach {
            $0.cancel()
        }
    }

    // MARK: - WalletConnectService

    func set(listener: WalletConnectServiceDelegate) {
        let weakListener = WeakWrapper(target: listener)
        listeners.append(weakListener)
    }

    func connect(uri: String) async throws {
        let walletConnectUri: WalletConnectURI

        do {
            walletConnectUri = try WalletConnectURI(uriString: uri)
        } catch {
            let preferredLanguages = LocalizationManager.shared.selectedLocale.rLanguages
            let title = R.string.localizable.walletConnectInvalidUrlTitle(preferredLanguages: preferredLanguages)
            let message = R.string.localizable.walletConnectInvalidUrlMessage(preferredLanguages: preferredLanguages)
            throw ConvenienceContentError(title: title, message: message)
        }

        try await WalletKit.instance.pair(uri: walletConnectUri)
    }

    func getSessions() -> [Session] {
        WalletKit.instance.getSessions()
    }

    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] {
        guard let legacyStorageMigrator = legacyStorageMigrator else {
            return []
        }

        return legacyStorageMigrator.legacySessionsNeedingReconnect(
            activeTopics: Set(getSessions().map(\.topic))
        )
    }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        switch proposalDecision {
        case let .approve(proposal, namespaces):
            _ = try await WalletKit.instance.approve(proposalId: proposal.id, namespaces: namespaces)
        case let .reject(proposal):
            try await WalletKit.instance.rejectSession(proposalId: proposal.id, reason: RejectionReason.userRejected)
        }
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        switch signDecision {
        case let .signed(request, signature):
            // A signature never reaches a dApp while signing is unavailable.
            guard signingPolicy.isEnabled else {
                throw WalletConnectSigningError.unavailable
            }
            try await respond(request, .response(signature))
        case let .rejected(request, error):
            try await respond(request, .error(error))
        }
    }

    /// Routes a dApp request. While signing is unavailable the dApp is told the user
    /// rejected it, no confirmation opens and no key is read.
    func handle(request: Request, session: Session?) {
        guard signingPolicy.isEnabled else {
            Task { [respond] in
                do {
                    try await respond(request, .error(.userRejected))
                } catch {
                    Logger.shared.error("WalletConnect could not decline a request while signing is unavailable")
                }
            }
            listeners.forEach {
                ($0.target as? WalletConnectServiceDelegate)?.signingUnavailable(request: request, session: session)
            }
            return
        }

        listeners.forEach {
            ($0.target as? WalletConnectServiceDelegate)?.sign(request: request, session: session)
        }
    }

    func disconnect(topic: String) async throws {
        try await WalletKit.instance.disconnect(topic: topic)
    }

    // MARK: - Private methods

    private func setupSubscription() {
        WalletKit.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposal, _ in
                guard let self = self else {
                    return
                }
                self.listeners.forEach {
                    ($0.target as? WalletConnectServiceDelegate)?.session(proposal: proposal)
                }
            }
            .store(in: &cancellablesBag)

        WalletKit.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self = self else {
                    return
                }
                self.listeners.forEach {
                    ($0.target as? WalletConnectServiceDelegate)?.didChange(sessions: sessions)
                }
            }
            .store(in: &cancellablesBag)

        WalletKit.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request, _ in
                guard let self = self else {
                    return
                }
                let session = WalletKit.instance.getSessions().first { $0.topic == request.topic }
                self.handle(request: request, session: session)
            }
            .store(in: &cancellablesBag)
    }
}
