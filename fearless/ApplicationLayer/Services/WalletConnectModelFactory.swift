import Foundation
import WalletConnectSign
import SSFModels

protocol WalletConnectModelFactory {
    func createSessionNamespaces(
        from proposal: Session.Proposal,
        wallets: [MetaAccountModel],
        chains: [ChainModel],
        optionalChainIds: [ChainModel.Id]?
    ) throws -> [String: SessionNamespace]

    func resolveChain(
        for blockchain: Blockchain,
        chains: [ChainModel]
    ) throws -> ChainModel

    func resolveChains(
        for blockchains: Set<Blockchain>,
        chains: [ChainModel]
    ) -> [ChainModel]

    func parseMethod(
        from request: Request
    ) throws -> WalletConnectMethod
}

final class WalletConnectModelFactoryImpl: WalletConnectModelFactory {
    func createSessionNamespaces(
        from proposal: Session.Proposal,
        wallets: [MetaAccountModel],
        chains: [ChainModel],
        optionalChainIds: [ChainModel.Id]?
    ) throws -> [String: SessionNamespace] {
        let requiredNamespaces = proposal.requiredNamespaces.map { $0.value }
        let optionalNamespaces = proposal.optionalNamespaces.or([:]).map { $0.value }

        let requiredBlockChains = createChainsResolution(
            from: proposal,
            chains: chains
        ).allBlockChains()

        let requiredMethods = requiredNamespaces.map { $0.methods }.reduce([], +)
        let requiredEvents = requiredNamespaces.map { $0.events }.reduce([], +)
        let requiredBlockchains = requiredNamespaces.compactMap { $0.chains }.reduce([], +)

        let requiredAccounts = wallets.map {
            createAccounts(
                wallet: $0,
                blockchains: requiredBlockchains,
                resolvedChains: requiredBlockChains
            )
        }.reduce([], +)

        let optionalBlockChains = createChainsResolution(
            from: proposal,
            chains: chains.filter { optionalChainIds?.contains($0.chainId) == true }
        ).allBlockChains()

        let optionalMethods = optionalNamespaces.map { $0.methods }.reduce([], +)
        let optionalEvents = optionalNamespaces.map { $0.events }.reduce([], +)
        let optionalBlockchains = optionalNamespaces.compactMap { $0.chains }.reduce([], +)

        let optionalAccounts = wallets.map {
            createAccounts(
                wallet: $0,
                blockchains: optionalBlockchains,
                resolvedChains: optionalBlockChains
            )
        }.reduce([], +)

        let sessionProposal = try AutoNamespaces.build(
            sessionProposal: proposal,
            chains: requiredBlockChains.map { $0.blockchain } + optionalBlockChains.map { $0.blockchain },
            methods: requiredMethods + optionalMethods,
            events: requiredEvents + optionalEvents,
            accounts: requiredAccounts + optionalAccounts
        )
        return sessionProposal
    }

    func resolveChain(
        for blockchain: Blockchain,
        chains: [ChainModel]
    ) throws -> ChainModel {
        let resolution = resolveChains(from: [blockchain], chains: chains)
        guard let chain = resolution.allowed.first?.chain else {
            throw JSONRPCError.unauthorizedChain
        }
        return chain
    }

    func resolveChains(
        for blockchains: Set<Blockchain>,
        chains: [ChainModel]
    ) -> [ChainModel] {
        resolveChains(from: blockchains, chains: chains).allowed.map { $0.chain }
    }

    func parseMethod(from request: Request) throws -> WalletConnectMethod {
        guard let method = WalletConnectMethod(rawValue: request.method) else {
            throw JSONRPCError.unauthorizedMethod
        }
        return method
    }

    // MARK: - Private methods

    private func createChainsResolution(
        from proposal: Session.Proposal,
        chains: [ChainModel]
    ) -> WalletConnectChainsResolution {
        let requiredBlockchains = proposal.requiredNamespaces
            .map { $0.value }
            .map { $0.chains }
            .compactMap { $0 }
            .reduce([], +)

        let requiredChains = resolveChains(
            from: Set(requiredBlockchains),
            chains: chains
        )

        let optionalBlockchains = proposal.optionalNamespaces.or([:])
            .map { $0.value }
            .map { $0.chains }
            .compactMap { $0 }
            .reduce([], +)

        let optionalChains = resolveChains(
            from: Set(optionalBlockchains),
            chains: chains
        )

        let resolution = WalletConnectChainsResolution(
            requiredChains: requiredChains,
            optionalChains: optionalChains
        )

        return resolution
    }

    private func resolveChains(
        from blockchains: Set<Blockchain>,
        chains: [ChainModel]
    ) -> ChainsResolution {
        let resolution = chains.reduce(into: ChainsResolution(allowed: [], forbidden: [])) { partialResult, chain in
            blockchains.forEach { blockchain in
                if
                    let caip2ChainId = Caip2ChainId(raw: blockchain.absoluteString),
                    chain.match(caip2ChainId) {
                    let blockChain = BlockChain(blockchain: blockchain, chain: chain)
                    partialResult.allowed.append(blockChain)
                } else {
                    partialResult.forbidden.insert(blockchain)
                }
            }
        }
        return resolution
    }

    private func createAccounts(
        wallet: MetaAccountModel,
        blockchains: [Blockchain],
        resolvedChains: [BlockChain]
    ) -> [Account] {
        let accounts: [Account] = blockchains.compactMap { blockchain in
            guard
                let blockChain = resolvedChains.first(where: { $0.blockchain == blockchain }),
                let account = wallet.fetch(for: blockChain.chain.accountRequest()),
                let address = account.toAddress()
            else {
                return nil
            }

            return Account(blockchain: blockchain, address: address)
        }
        return accounts
    }
}
