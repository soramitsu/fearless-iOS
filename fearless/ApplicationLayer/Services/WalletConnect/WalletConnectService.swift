import Foundation
import FearlessFoundation
import Combine
import WalletConnectSign
import ReownWalletKit

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
    private static let walletConnectGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet.walletconnect"

    private var listeners: [WeakWrapper] = []
    private var cancellablesBag = Set<AnyCancellable>()
    private let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) {
        self.localizationManager = localizationManager
    }

    // MARK: - ApplicationServiceProtocol

    func setup() {
        #if F_DEV
            let projectId = WalletConnectDebug.projectId
        #else
            let projectId = WalletConnect.projectId
        #endif
        Networking.configure(
            groupIdentifier: Self.walletConnectGroupIdentifier,
            projectId: projectId,
            socketFactory: WalletConnectSocketFactory()
        )
        WalletKit.configure(
            metadata: AppMetadata.createFearlessMetadata(),
            crypto: DefaultCryptoProvider()
        )
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
        let walletConnectUri: WalletConnectURI

        do {
            walletConnectUri = try WalletConnectURI(uriString: uri)
        } catch {
            let preferredLanguages = localizationManager.selectedLocale.rLanguages
            let title = R.string.localizable.walletConnectInvalidUrlTitle(preferredLanguages: preferredLanguages)
            let message = R.string.localizable.walletConnectInvalidUrlMessage(preferredLanguages: preferredLanguages)
            throw ConvenienceContentError(title: title, message: message)
        }

        try await WalletKit.instance.pair(uri: walletConnectUri)
    }

    func getSessions() -> [Session] {
        WalletKit.instance.getSessions()
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
            try await WalletKit.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .response(signature)
            )
        case let .rejected(request, error):
            try await WalletKit.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(error)
            )
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
                self.listeners.forEach {
                    ($0.target as? WalletConnectServiceDelegate)?.sign(request: request, session: session)
                }
            }
            .store(in: &cancellablesBag)
    }
}
