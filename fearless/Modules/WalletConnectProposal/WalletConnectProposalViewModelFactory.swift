import Foundation
import WalletConnectSign
import SSFModels

protocol WalletConnectProposalViewModelFactory {
    func buildProposalSessionViewModel(
        proposal: Session.Proposal,
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel

    func buildActiveSessionViewModel(
        session: Session,
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel

    func didTapOn(
        _ indexPath: IndexPath,
        cells: [WalletConnectProposalCellModel]
    ) -> WalletConnectProposalViewModel?
}

final class WalletConnectProposalViewModelFactoryImpl: WalletConnectProposalViewModelFactory {
    private let walletConnectModelFactory: WalletConnectModelFactory
    private let status: WalletConnectProposalPresenter.SessionStatus

    init(
        status: WalletConnectProposalPresenter.SessionStatus,
        walletConnectModelFactory: WalletConnectModelFactory
    ) {
        self.status = status
        self.walletConnectModelFactory = walletConnectModelFactory
    }

    func buildProposalSessionViewModel(
        proposal: Session.Proposal,
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale _: Locale
    ) throws -> WalletConnectProposalViewModel {
        let dApp = createDAppViewModel(from: proposal)

        guard let requiredNetwroks = try createNetworksViewModel(
            from: proposal.requiredNamespaces,
            chains: chains,
            title: "Required networks"
        ) else {
            throw JSONRPCError.unauthorizedChain
        }

        let optionalNetworks = try createNetworksViewModel(
            from: proposal.optionalNamespaces,
            chains: chains,
            title: "Optional networks"
        )

        guard let requiredExpandable = try createProposalPermissionsViewModel(
            from: proposal.requiredNamespaces,
            chains: chains,
            cellTitle: "Review required permissions"
        ) else {
            throw JSONRPCError.unauthorizedChain
        }

        let optionalExpandable = try createProposalPermissionsViewModel(
            from: proposal.optionalNamespaces,
            chains: chains,
            cellTitle: "Review optional permissions"
        )

        let walletCellViewModels = createWalletsCellModels(from: wallets, forActiveSession: false)

        let infoCells = [
            WalletConnectProposalCellModel.dAppInfo(dApp),
            WalletConnectProposalCellModel.requiredNetworks(requiredNetwroks),
            WalletConnectProposalCellModel.requiredExpandable(requiredExpandable),
            WalletConnectProposalCellModel(optionalNetworksCaseViewModel: optionalNetworks),
            WalletConnectProposalCellModel(optionalNetworkExpadableViewModel: optionalExpandable)
        ].compactMap { $0 }

        let cells = [infoCells, walletCellViewModels].reduce([], +)

        return WalletConnectProposalViewModel(
            indexPath: nil,
            cells: cells,
            expiryDate: nil
        )
    }

    func buildActiveSessionViewModel(
        session: Session,
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel {
        let dApp = WalletConnectProposalCellModel.DetailsViewModel(
            title: session.peer.name,
            subtitle: URL(string: session.peer.url)?.host ?? session.peer.url,
            icon: RemoteImageViewModel(string: session.peer.url)
        )

        guard let requiredExpandable = try createSessionPermissionsViewModel(
            from: session.namespaces,
            chains: chains,
            cellTitle: "Review permissions"
        ) else {
            throw JSONRPCError.unauthorizedChain
        }

        let blockchains = Set(session.requiredNamespaces.map { $0.value }.compactMap { $0.chains }.reduce([], +))
        let sessionWallets = try findWallets(
            for: session.accounts.map { $0.address },
            blockchains: blockchains,
            wallets: wallets,
            chains: chains
        )

        let infoCells = [
            WalletConnectProposalCellModel.dAppInfo(dApp),
            WalletConnectProposalCellModel.requiredExpandable(requiredExpandable)
        ].compactMap { $0 }

        let walletCellViewModels = createWalletsCellModels(from: sessionWallets, forActiveSession: true)
        let cells = [infoCells, walletCellViewModels].reduce([], +)

        let dateString = DateFormatter.connectionExpiry.value(for: locale).string(from: session.expiryDate)

        return WalletConnectProposalViewModel(
            indexPath: nil,
            cells: cells,
            expiryDate: dateString
        )
    }

    func didTapOn(
        _ indexPath: IndexPath,
        cells: [WalletConnectProposalCellModel]
    ) -> WalletConnectProposalViewModel? {
        guard let viewModel = cells[safe: indexPath.row] else {
            return nil
        }

        var updatedCells = cells
        switch viewModel {
        case .dAppInfo, .requiredNetworks, .optionalNetworks:
            return nil
        case let .requiredExpandable(viewModel):
            let toggledViewModel = viewModel.toggle()
            updatedCells[indexPath.row] = .requiredExpandable(toggledViewModel)
        case let .optionalExpandable(viewModel):
            let toggledViewModel = viewModel.toggle()
            updatedCells[indexPath.row] = .optionalExpandable(toggledViewModel)
        case let .wallet(viewModel):
            guard case .proposal = status else {
                return nil
            }
            let toggledViewModel = viewModel.toggle()
            updatedCells[indexPath.row] = .wallet(toggledViewModel)
        }

        return WalletConnectProposalViewModel(
            indexPath: indexPath,
            cells: updatedCells,
            expiryDate: nil
        )
    }

    // MARK: - Private methods

    private func createDAppViewModel(
        from proposal: Session.Proposal
    ) -> WalletConnectProposalCellModel.DetailsViewModel {
        WalletConnectProposalCellModel.DetailsViewModel(
            title: proposal.proposer.name,
            subtitle: URL(string: proposal.proposer.url)?.host ?? proposal.proposer.url,
            icon: RemoteImageViewModel(string: proposal.proposer.url)
        )
    }

    private func createNetworksViewModel(
        from namespaces: [String: ProposalNamespace]?,
        chains: [ChainModel],
        title: String
    ) throws -> WalletConnectProposalCellModel.DetailsViewModel? {
        guard let namespaces = namespaces else { return nil }
        let blockchains = namespaces
            .map { $0.value }
            .map { $0.chains }
            .compactMap { $0 }
            .reduce([], +)

        let resolvedChains = try blockchains.map {
            try walletConnectModelFactory.resolveChain(for: $0, chains: chains)
        }

        let subtitle = resolvedChains
            .map { $0.name }
            .joined(separator: ", ")

        return WalletConnectProposalCellModel.DetailsViewModel(
            title: title,
            subtitle: subtitle,
            icon: nil
        )
    }

    private func createProposalPermissionsViewModel(
        from namespaces: [String: ProposalNamespace]?,
        chains: [ChainModel],
        cellTitle: String
    ) throws -> WalletConnectProposalCellModel.ExpandableViewModel? {
        guard let namespaces = namespaces else {
            return nil
        }
        let blockchains = namespaces
            .map { $0.value }
            .map { $0.chains }
            .compactMap { $0 }
            .reduce([], +)

        let resolvedChains = walletConnectModelFactory.resolveChains(
            for: Set(blockchains),
            chains: chains
        )

        let methods = namespaces
            .map { $0.value }
            .map { $0.methods }
            .reduce([], +)
            .joined(separator: ", ")

        let events = namespaces
            .map { $0.value }
            .map { $0.events }
            .reduce([], +)
            .joined(separator: ", ")

        return WalletConnectProposalCellModel.ExpandableViewModel(
            cellTitle: cellTitle,
            chain: resolvedChains.map { $0.name }.joined(separator: ", "),
            methods: methods,
            events: events,
            isExpanded: false
        )
    }

    private func createSessionPermissionsViewModel(
        from namespaces: [String: SessionNamespace],
        chains: [ChainModel],
        cellTitle: String
    ) throws -> WalletConnectProposalCellModel.ExpandableViewModel? {
        let blockchains = namespaces
            .map { $0.value }
            .map { $0.chains }
            .compactMap { $0 }
            .reduce([], +)

        let resolvedChains = walletConnectModelFactory.resolveChains(
            for: Set(blockchains),
            chains: chains
        )

        let methods = namespaces
            .map { $0.value }
            .map { $0.methods }
            .reduce([], +)
            .joined(separator: ", ")

        let events = namespaces
            .map { $0.value }
            .map { $0.events }
            .reduce([], +)
            .joined(separator: ", ")

        return WalletConnectProposalCellModel.ExpandableViewModel(
            cellTitle: cellTitle,
            chain: resolvedChains.map { $0.name }.joined(separator: ", "),
            methods: methods,
            events: events,
            isExpanded: false
        )
    }

    private func createWalletsCellModels(
        from wallets: [MetaAccountModel],
        forActiveSession: Bool
    ) -> [WalletConnectProposalCellModel] {
        wallets.enumerated().map { index, wallet in
            let viewModel = WalletConnectProposalCellModel.WalletViewModel(
                metaId: wallet.metaId,
                walletName: wallet.name,
                isSelected: forActiveSession ? true : index == 0
            )
            return WalletConnectProposalCellModel.wallet(viewModel)
        }
    }

    private func findWallets(
        for addresses: [String],
        blockchains: Set<Blockchain>,
        wallets: [MetaAccountModel],
        chains: [ChainModel]
    ) throws -> [MetaAccountModel] {
        let resolveChains = walletConnectModelFactory.resolveChains(for: blockchains, chains: chains)

        let wallet = wallets.compactMap { wallet in
            let chain = resolveChains.first { chain in
                let accountRequest = chain.accountRequest()
                guard let walletAddress = wallet.fetch(for: accountRequest)?.toAddress() else {
                    return false
                }
                return addresses.contains(walletAddress)
            }
            return chain == nil ? nil : wallet
        }
        return wallet
    }
}
