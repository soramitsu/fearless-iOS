import Foundation
import SoraFoundation
import Combine
import WalletConnectSign
import Web3Wallet
import FearlessKeys

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
        #if F_DEV
            let projectId = WalletConnectDebug.projectId
        #else
            let projectId = WalletConnect.projectId
        #endif
        Networking.configure(
            projectId: projectId,
            socketFactory: WalletConnectSocketFactory()
        )
        Web3Wallet.configure(
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
        guard let walletConnectUri = WalletConnectURI(string: uri) else {
            let preferredLanguages = LocalizationManager.shared.selectedLocale.rLanguages
            let title = R.string.localizable.walletConnectInvalidUrlTitle(preferredLanguages: preferredLanguages)
            let message = R.string.localizable.walletConnectInvalidUrlMessage(preferredLanguages: preferredLanguages)
            throw ConvenienceContentError(title: title, message: message)
        }
        try await Web3Wallet.instance.pair(uri: walletConnectUri)
    }

    func getSessions() -> [Session] {
        Web3Wallet.instance.getSessions()
    }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        switch proposalDecision {
        case let .approve(proposal, namespaces):
            try await Web3Wallet.instance.approve(proposalId: proposal.id, namespaces: namespaces)
        case let .reject(proposal):
            try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .userRejected)
        }
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        switch signDecision {
        case let .signed(request, signature):
            try await Web3Wallet.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .response(signature)
            )
        case let .rejected(request, error):
            try await Web3Wallet.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(error)
            )
        }
    }

    func disconnect(topic: String) async throws {
        try await Web3Wallet.instance.disconnect(topic: topic)
    }

    // MARK: - Private methods

    private func setupSubscription() {
        Web3Wallet.instance.sessionProposalPublisher
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

        Web3Wallet.instance.sessionsPublisher
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

        Web3Wallet.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request, _ in
                guard let self = self else {
                    return
                }
                let session = Web3Wallet.instance.getSessions().first { $0.topic == request.topic }
                self.listeners.forEach {
                    ($0.target as? WalletConnectServiceDelegate)?.sign(request: request, session: session)
                }
            }
            .store(in: &cancellablesBag)
    }
}
