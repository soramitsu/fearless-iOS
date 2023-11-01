import Foundation
import SSFModels
import WalletConnectSign

protocol WalletConnectDisconnectService {
    func disconnect(wallet: MetaAccountModel) async throws
    func disconnectAllSessions()
}

final class WalletConnectDisconnectServiceImpl: WalletConnectDisconnectService {
    private let walletConnectService = WalletConnectServiceImpl.shared
    private let walletConnectModelFactory: WalletConnectModelFactory
    private let chainAssetFetcher: ChainAssetFetchingProtocol

    init(
        walletConnectModelFactory: WalletConnectModelFactory,
        chainAssetFetcher: ChainAssetFetchingProtocol
    ) {
        self.walletConnectModelFactory = walletConnectModelFactory
        self.chainAssetFetcher = chainAssetFetcher
    }

    // MARK: - WalletConnectDisconnectService

    func disconnect(wallet: MetaAccountModel) async throws {
        let connectedSessions = walletConnectService.getSessions()
        let session = try await findSessionForDisconnect(sessions: connectedSessions, wallet: wallet)
        try await walletConnectService.disconnect(topic: session.topic)
    }

    func disconnectAllSessions() {
        let sessions = walletConnectService.getSessions()
        sessions.forEach { session in
            Task {
                try await walletConnectService.disconnect(topic: session.topic)
            }
        }
    }

    // MARK: - Private methods

    private func fetchChains() async throws -> [ChainModel] {
        try await chainAssetFetcher.fetchAwait(shouldUseCache: true, filters: [], sortDescriptors: []).map { $0.chain }
    }

    private func findSessionForDisconnect(sessions: [Session], wallet: MetaAccountModel) async throws -> Session {
        let chains = try await fetchChains()
        let connectedSession = sessions.first { session in
            walletHas(session: session, wallet: wallet, chains: chains)
        }
        guard let connectedSession = connectedSession else {
            throw ConvenienceError(error: "Session was not finded")
        }
        return connectedSession
    }

    private func walletHas(
        session: Session,
        wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> Bool {
        let blockchains = Set(session.requiredNamespaces.map { $0.value }.compactMap { $0.chains }.reduce([], +))
        let resolveChains = walletConnectModelFactory.resolveChains(for: blockchains, chains: chains)
        let addresses = session.accounts.map { $0.address }

        let connectedChain = resolveChains.first { chain in
            let accountRequest = chain.accountRequest()
            guard let address = wallet.fetch(for: accountRequest)?.toAddress() else {
                return false
            }
            return addresses.contains(address)
        }
        return connectedChain != nil
    }
}
