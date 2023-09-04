import Foundation
import Combine
import WalletConnectSign
import Web3Wallet

protocol WalletConnectService: ApplicationServiceProtocol {
    func set(delegate: WalletConnectServiceDelegate)
    func connect(uri: String) throws
    func getSessions() -> [Session]

    func submit(proposalDecision: WalletConnectProposalDecision) async throws
    func submit(signDecision: WalletConnectSignDecision) async throws
}

protocol WalletConnectServiceDelegate: AnyObject {
    func session(proposal: Session.Proposal)
    func sign(request: Request, session: Session?)
}

final class WalletConnectServiceImpl: WalletConnectService {
    static let shared = WalletConnectServiceImpl()

    private weak var delegate: WalletConnectServiceDelegate?
    private var cancellablesBag = Set<AnyCancellable>()

    private init() {}

    // MARK: - // MARK: - ApplicationServiceProtocol

    func setup() {
        Networking.configure(
            projectId: "13e43f17a7bf1b5336ee835d8e057718",
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

    func set(delegate: WalletConnectServiceDelegate) {
        self.delegate = delegate
    }

    func connect(uri: String) throws {
        guard let walletConnectUri = WalletConnectURI(string: uri) else {
            throw ConvenienceError(error: "Invalid uri")
        }
        Task {
            do {
                try await Web3Wallet.instance.pair(uri: walletConnectUri)
            } catch {
                throw error
            }
        }
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

    // MARK: - Private methods

    private func setupSubscription() {
        Web3Wallet.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposal, context in
                guard let self = self else {
                    return
                }
                print(context)
                self.delegate?.session(proposal: proposal)
            }
            .store(in: &cancellablesBag)

        Web3Wallet.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self = self else {
                    return
                }
                print(sessions)
//                self.delegate?.walletConnect(service: self, didChange: sessions)
            }
            .store(in: &cancellablesBag)

        Web3Wallet.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request, context in
                guard let self = self else {
                    return
                }
                print(context)
                let session = Web3Wallet.instance.getSessions().first { $0.topic == request.topic }
                self.delegate?.sign(request: request, session: session)
            }
            .store(in: &cancellablesBag)
    }
}
