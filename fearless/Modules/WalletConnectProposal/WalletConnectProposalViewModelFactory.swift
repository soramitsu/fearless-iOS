import Foundation
import WalletConnectSign
import SSFModels

protocol WalletConnectProposalViewModelFactory {
    func buildViewModel(
        proposal: Session.Proposal,
        chains: [ChainModel],
        wallets: [MetaAccountModel]
    ) throws -> WalletConnectProposalViewModel
    func didTapOn(_ indexPath: IndexPath, cells: [WalletConnectProposalCellModel]) -> WalletConnectProposalViewModel?
}

final class WalletConnectProposalViewModelFactoryImpl: WalletConnectProposalViewModelFactory {
    private let walletConnectModelFactory: WalletConnectModelFactory

    init(walletConnectModelFactory: WalletConnectModelFactory) {
        self.walletConnectModelFactory = walletConnectModelFactory
    }

    func buildViewModel(
        proposal: Session.Proposal,
        chains: [ChainModel],
        wallets: [MetaAccountModel]
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

        guard let requiredExpandable = try createPermissionsViewModel(
            from: proposal.requiredNamespaces,
            chains: chains,
            cellTitle: "Review required permissions"
        ) else {
            throw JSONRPCError.unauthorizedChain
        }

        let optionalExpandable = try createPermissionsViewModel(
            from: proposal.optionalNamespaces,
            chains: chains,
            cellTitle: "Review optional permissions"
        )

        let walletCellViewModels = createWalletsCellModels(from: wallets)

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
            cells: cells
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
            let toggledViewModel = viewModel.toggle()
            updatedCells[indexPath.row] = .wallet(toggledViewModel)
        }

        return WalletConnectProposalViewModel(
            indexPath: indexPath,
            cells: updatedCells
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

    private func createPermissionsViewModel(
        from namespaces: [String: ProposalNamespace]?,
        chains: [ChainModel],
        cellTitle: String
    ) throws -> WalletConnectProposalCellModel.ExpandableViewModel? {
        guard let namespaces = namespaces else {
            return nil
        }
        let blockchain = namespaces
            .map { $0.value }
            .map { $0.chains }
            .compactMap { $0 }
            .reduce([], +)
            .first
        guard let blockchain = blockchain else {
            throw JSONRPCError.invalidParams
        }
        let resolvedChain = try walletConnectModelFactory.resolveChain(
            for: blockchain,
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
            chain: resolvedChain.name,
            methods: methods,
            events: events,
            isExpanded: false
        )
    }

    private func createWalletsCellModels(
        from wallets: [MetaAccountModel]
    ) -> [WalletConnectProposalCellModel] {
        wallets.enumerated().map { index, wallet in
            let viewModel = WalletConnectProposalCellModel.WalletViewModel(
                metaId: wallet.metaId,
                walletName: wallet.name,
                isSelected: index == 0
            )
            return WalletConnectProposalCellModel.wallet(viewModel)
        }
    }
}
