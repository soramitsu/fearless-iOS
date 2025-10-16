import Foundation
import SoraFoundation
import Combine
import WalletConnectSign
import Web3Wallet
#if canImport(ReownWalletKit)
import ReownWalletKit
#endif
#if canImport(FearlessKeys)
    import FearlessKeys
#else
    // Fallback names avoid clashing with the WalletConnect module name
    enum WalletConnectKeysDebug {
        static let projectId = ""
    }

    enum WalletConnectKeys {
        static let projectId = ""
    }
#endif

protocol WalletConnectService: ApplicationServiceProtocol {
    func set(listener: WalletConnectServiceDelegate)
    func connect(uri: String) async throws
    func disconnect(topic: String) async throws
    func getSessions() -> [Session]

    func submit(proposalDecision: WalletConnectProposalDecision) async throws
    func submit(signDecision: WalletConnectSignDecision) async throws
}

protocol WalletConnectServiceDelegate: AnyObject {
    func session(proposal: Session.Proposal)
    func sign(request: Request, session: Session?)
    func didChange(sessions: [Session])
}

extension WalletConnectServiceDelegate {
    func session(proposal _: Session.Proposal) {}
    func sign(request _: Request, session _: Session?) {}
    func didChange(sessions _: [Session]) {}
}

final class WalletConnectServiceImpl: WalletConnectService {
    static let shared = WalletConnectServiceImpl()

    private var listeners: [WeakWrapper] = []
    private var cancellablesBag = Set<AnyCancellable>()

    private init() {}

    // MARK: - ApplicationServiceProtocol

    func setup() {
        #if canImport(FearlessKeys)
            #if F_DEV
                let projectId = WalletConnectDebug.projectId
            #else
                let projectId = WalletConnect.projectId
            #endif
        #else
            #if F_DEV
                let projectId = WalletConnectKeysDebug.projectId
            #else
                let projectId = WalletConnectKeys.projectId
            #endif
        #endif
        let groupIdentifier = "group." + (Bundle.main.bundleIdentifier ?? "jp.co.soramitsu.fearlesswallet.dev")
        Networking.configure(
            groupIdentifier: groupIdentifier,
            projectId: projectId,
            socketFactory: WalletConnectSocketFactory()
        )
        #if canImport(ReownWalletKit)
            WalletKit.configure(
                metadata: AppMetadata.createFearlessMetadata(),
                crypto: DefaultCryptoProvider()
            )
        #else
            Web3Wallet.configure(
                metadata: AppMetadata.createFearlessMetadata(),
                crypto: DefaultCryptoProvider()
            )
        #endif
        setupSubscription()
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
        guard let walletConnectUri = WalletConnectURI(string: uri) else {
            let preferredLanguages = LocalizationManager.shared.selectedLocale.rLanguages
            let title = R.string.localizable.walletConnectInvalidUrlTitle(preferredLanguages: preferredLanguages)
            let message = R.string.localizable.walletConnectInvalidUrlMessage(preferredLanguages: preferredLanguages)
            throw ConvenienceContentError(title: title, message: message)
        }
        #if canImport(ReownWalletKit)
            try await WalletKit.instance.pair(uri: walletConnectUri)
        #else
            try await Web3Wallet.instance.pair(uri: walletConnectUri)
        #endif
    }

    func getSessions() -> [Session] {
        #if canImport(ReownWalletKit)
            return WalletKit.instance.getSessions()
        #else
            return Web3Wallet.instance.getSessions()
        #endif
    }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        switch proposalDecision {
        case let .approve(proposal, namespaces):
            #if canImport(ReownWalletKit)
                _ = try await WalletKit.instance.approve(proposalId: proposal.id, namespaces: namespaces)
            #else
                try await Web3Wallet.instance.approve(proposalId: proposal.id, namespaces: namespaces)
            #endif
        case let .reject(proposal):
            #if canImport(ReownWalletKit)
                try await WalletKit.instance.rejectSession(proposalId: proposal.id, reason: RejectionReason.userRejected)
            #else
                // Fallback: disconnect pairing to reflect rejection on older SDKs without explicit reject API
                try await Web3Wallet.instance.disconnectPairing(topic: proposal.pairingTopic)
            #endif
        }
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        switch signDecision {
        case let .signed(request, signature):
            #if canImport(ReownWalletKit)
                try await WalletKit.instance.respond(
                    topic: request.topic,
                    requestId: request.id,
                    response: .response(signature)
                )
            #else
                try await Web3Wallet.instance.respond(
                    topic: request.topic,
                    requestId: request.id,
                    response: .response(signature)
                )
            #endif
        case let .rejected(request, error):
            #if canImport(ReownWalletKit)
                try await WalletKit.instance.respond(
                    topic: request.topic,
                    requestId: request.id,
                    response: .error(error)
                )
            #else
                try await Web3Wallet.instance.respond(
                    topic: request.topic,
                    requestId: request.id,
                    response: .error(error)
                )
            #endif
        }
    }

    func disconnect(topic: String) async throws {
        #if canImport(ReownWalletKit)
            try await WalletKit.instance.disconnect(topic: topic)
        #else
            try await Web3Wallet.instance.disconnect(topic: topic)
        #endif
    }

    // MARK: - Private methods

    private func setupSubscription() {
        #if canImport(ReownWalletKit)
        WalletKit.instance.sessionProposalPublisher
        #else
        Web3Wallet.instance.sessionProposalPublisher
        #endif
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

        #if canImport(ReownWalletKit)
        WalletKit.instance.sessionsPublisher
        #else
        Web3Wallet.instance.sessionsPublisher
        #endif
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

        #if canImport(ReownWalletKit)
        WalletKit.instance.sessionRequestPublisher
        #else
        Web3Wallet.instance.sessionRequestPublisher
        #endif
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request, _ in
                guard let self = self else {
                    return
                }
                #if canImport(ReownWalletKit)
                let session = WalletKit.instance.getSessions().first { $0.topic == request.topic }
                #else
                let session = Web3Wallet.instance.getSessions().first { $0.topic == request.topic }
                #endif
                self.listeners.forEach {
                    ($0.target as? WalletConnectServiceDelegate)?.sign(request: request, session: session)
                }
            }
            .store(in: &cancellablesBag)
    }
}
