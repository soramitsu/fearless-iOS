import Foundation
import WalletConnectSign
import SSFModels

protocol WalletConnectProposalViewModelFactory {
    func buildViewModel(
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
    private let status: SessionStatus

    init(
        status: SessionStatus,
        walletConnectModelFactory: WalletConnectModelFactory
    ) {
        self.status = status
        self.walletConnectModelFactory = walletConnectModelFactory
    }

    func buildViewModel(
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel {
        let wallets = filterWallets(wallets: wallets)
        switch status {
        case let .proposal(connectProposal):
            switch connectProposal {
            case .walletConnect:
                return try buildWalletConenctProposalSessionViewModel(
                    chains: chains,
                    wallets: wallets,
                    locale: locale
                )
            case .tonJsBridge, .tonConnect:
                return try buildTonConenctProposalSessionViewModel(
                    chains: chains,
                    wallets: wallets,
                    locale: locale
                )
            }
        case let .active(actionConnect):
            switch actionConnect {
            case .walletConnect:
                return try buildWalletConnectActiveSessionViewModel(
                    chains: chains,
                    wallets: wallets,
                    locale: locale
                )
            case .tonConnect:
                return try buildTonConenctActiveSessionViewModel(
                    chains: chains,
                    wallets: wallets,
                    locale: locale
                )
            }
        }
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
            switch status {
            case let .proposal(connectProposal):
                switch connectProposal {
                case .walletConnect:
                    let toggledViewModel = viewModel.toggle()
                    updatedCells[indexPath.row] = .wallet(toggledViewModel)
                case .tonJsBridge, .tonConnect:
                    updatedCells = cells.map { $0.deselectWallet() }
                    let toggledViewModel = viewModel.toggle()
                    updatedCells[indexPath.row] = .wallet(toggledViewModel)
                }
            case .active:
                break
            }
        }

        return WalletConnectProposalViewModel(
            indexPath: indexPath,
            cells: updatedCells,
            expiryDate: nil
        )
    }

    // MARK: - Private methods
    
    private func filterWallets(wallets: [MetaAccountModel]) -> [MetaAccountModel] {
        return wallets.filter { wallet in
            switch status {
            case .proposal(let connectProposal):
                switch connectProposal {
                case .walletConnect:
                    return wallet.ecosystem.isRegular
                case .tonJsBridge, .tonConnect:
                    return wallet.ecosystem.isTon
                }
            case .active(let actionConnect):
                switch actionConnect {
                case .walletConnect:
                    return wallet.ecosystem.isRegular
                case .tonConnect:
                    return wallet.ecosystem.isTon
                }
            }
        }
    }

    private func createDAppViewModel() -> WalletConnectProposalCellModel.DetailsViewModel {
        switch status {
        case let .proposal(proposal):
            switch proposal {
            case let .walletConnect(proposal):
                return WalletConnectProposalCellModel.DetailsViewModel(
                    title: proposal.proposer.name,
                    subtitle: URL(string: proposal.proposer.url)?.host ?? proposal.proposer.url,
                    icon: RemoteImageViewModel(string: proposal.proposer.icons.first)
                )
            case let .tonJsBridge(manifest, _, _, _):
                return WalletConnectProposalCellModel.DetailsViewModel(
                    title: manifest.name,
                    subtitle: manifest.host,
                    icon: RemoteImageViewModel(url: manifest.iconUrl)
                )
            case let .tonConnect(manifest, _):
                return WalletConnectProposalCellModel.DetailsViewModel(
                    title: manifest.name,
                    subtitle: manifest.host,
                    icon: RemoteImageViewModel(url: manifest.iconUrl)
                )
            }
        case let .active(session):
            switch session {
            case let .walletConnect(session):
                return WalletConnectProposalCellModel.DetailsViewModel(
                    title: session.peer.name,
                    subtitle: URL(string: session.peer.url)?.host ?? session.peer.url,
                    icon: RemoteImageViewModel(string: session.peer.url)
                )
            case let .tonConnect(app, _):
                return WalletConnectProposalCellModel.DetailsViewModel(
                    title: app.name,
                    subtitle: app.appUrl.host ?? "",
                    icon: RemoteImageViewModel(url: app.iconUrl)
                )
            }
        }
    }

    // MARK: - Private wallet connect methods

    func buildWalletConenctProposalSessionViewModel(
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel {
        guard let proposal = status.proposal else {
            throw ConvenienceError(error: "Missing wallet connect proposal")
        }
        let dApp = createDAppViewModel()

        let requiredNetworks = try createNetworksViewModel(
            from: proposal.requiredNamespaces,
            chains: chains,
            title: R.string.localizable.requiredNetworks(preferredLanguages: locale.rLanguages),
            isRequired: true
        )

        let optionalNetworks = try? createNetworksViewModel(
            from: proposal.optionalNamespaces,
            chains: chains,
            title: R.string.localizable.optionalNetworks(preferredLanguages: locale.rLanguages),
            isRequired: false
        )

        let requiredExpandable = try createProposalPermissionsViewModel(
            from: proposal.requiredNamespaces,
            chains: chains,
            cellTitle: R.string.localizable.reviewRequiredPermissions(preferredLanguages: locale.rLanguages),
            locale: locale
        )

        let optionalExpandable = try? createProposalPermissionsViewModel(
            from: proposal.optionalNamespaces,
            chains: chains,
            cellTitle: R.string.localizable.reviewOptionalPermissions(preferredLanguages: locale.rLanguages),
            locale: locale
        )

        let walletCellViewModels = createWalletsCellModels(from: wallets, forActiveSession: false)

        let infoCells = [
            WalletConnectProposalCellModel.dAppInfo(dApp),
            WalletConnectProposalCellModel(requiredNetworksViewModel: requiredNetworks),
            WalletConnectProposalCellModel(requiredExpandableViewModel: requiredExpandable),
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

    func buildWalletConnectActiveSessionViewModel(
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel {
        guard let session = status.session else {
            throw ConvenienceError(error: "Missing wallet connect session")
        }
        let dApp = createDAppViewModel()

        guard let requiredExpandable = try createSessionPermissionsViewModel(
            from: session.namespaces,
            chains: chains,
            cellTitle: R.string.localizable.reviewPermissions(preferredLanguages: locale.rLanguages),
            locale: locale
        ) else {
            throw AutoNamespacesError.requiredChainsNotSatisfied
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

    private func createNetworksViewModel(
        from namespaces: [String: ProposalNamespace]?,
        chains: [ChainModel],
        title: String,
        isRequired: Bool
    ) throws -> WalletConnectProposalCellModel.DetailsViewModel? {
        guard let namespaces = namespaces else { return nil }
        let blockchains = namespaces
            .map { $0.value }
            .map { $0.chains }
            .compactMap { $0 }
            .reduce([], +)

        let resolvedChains = walletConnectModelFactory.resolveChains(for: Set(blockchains), chains: chains)
        if isRequired, blockchains.count > resolvedChains.count {
            throw AutoNamespacesError.requiredChainsNotSatisfied
        } else if resolvedChains.isEmpty {
            return nil
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
        cellTitle: String,
        locale: Locale
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

        if methods.isEmpty, events.isEmpty, resolvedChains.isEmpty {
            return nil
        }

        return WalletConnectProposalCellModel.ExpandableViewModel(
            cellTitle: cellTitle,
            title: resolvedChains.map { $0.name }.joined(separator: ", "),
            title2: R.string.localizable.commonMethods(preferredLanguages: locale.rLanguages),
            subtitle2: methods,
            title3: R.string.localizable.commonEvents(preferredLanguages: locale.rLanguages),
            subtitle3: events,
            isExpanded: false
        )
    }

    private func createSessionPermissionsViewModel(
        from namespaces: [String: SessionNamespace],
        chains: [ChainModel],
        cellTitle: String,
        locale: Locale
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
            title: resolvedChains.map { $0.name }.joined(separator: ", "),
            title2: R.string.localizable.commonMethods(preferredLanguages: locale.rLanguages),
            subtitle2: methods,
            title3: R.string.localizable.commonEvents(preferredLanguages: locale.rLanguages),
            subtitle3: events,
            isExpanded: false
        )
    }

    private func createWalletsCellModels(
        from wallets: [MetaAccountModel],
        forActiveSession: Bool
    ) -> [WalletConnectProposalCellModel] {
        let selectedWallet = SelectedWalletSettings.shared.value
        return wallets.enumerated().map { index, wallet in
            let viewModel = WalletConnectProposalCellModel.WalletViewModel(
                metaId: wallet.metaId,
                walletName: wallet.name,
                isSelected: forActiveSession ? true : wallet.metaId == selectedWallet?.metaId,
                icon: wallet.ecosystem.isRegular ? R.image.iconBirdGreen()! : R.image.tonIcon()!
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

    // MARK: - Private ton connect methods

    func buildTonConenctProposalSessionViewModel(
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel {
        guard
            let manifest = status.tonManifest,
            let tonChain = chains.first(where: { $0.ecosystem == .ton })
        else {
            throw ConvenienceError(error: "Missing wallet connect proposal")
        }
        let dApp = createDAppViewModel()

        let requiredNetworks = WalletConnectProposalCellModel.DetailsViewModel(
            title: R.string.localizable.requiredNetworks(preferredLanguages: locale.rLanguages),
            subtitle: tonChain.name,
            icon: RemoteImageViewModel(url: tonChain.icon)
        )

        let walletCellViewModels = createWalletsCellModels(from: wallets, forActiveSession: false)

        let requiredExpandableViewModel = WalletConnectProposalCellModel.ExpandableViewModel(
            cellTitle: R.string.localizable.tonConnectAlertTitle(preferredLanguages: locale.rLanguages),
            title: R.string.localizable.tonConnectAlertSubtitle(preferredLanguages: locale.rLanguages),
            title2: R.string.localizable.tonConnectAlertDescription(preferredLanguages: locale.rLanguages),
            subtitle2: manifest.url.absoluteString,
            title3: nil,
            subtitle3: nil,
            isExpanded: false
        )

        let infoCells = [
            WalletConnectProposalCellModel.dAppInfo(dApp),
            WalletConnectProposalCellModel(requiredNetworksViewModel: requiredNetworks),
            WalletConnectProposalCellModel(requiredExpandableViewModel: requiredExpandableViewModel)
        ].compactMap { $0 }

        let cells = [infoCells, walletCellViewModels].reduce([], +)

        return WalletConnectProposalViewModel(
            indexPath: nil,
            cells: cells,
            expiryDate: nil
        )
    }
    
    func buildTonConenctActiveSessionViewModel(
        chains: [ChainModel],
        wallets: [MetaAccountModel],
        locale: Locale
    ) throws -> WalletConnectProposalViewModel {
        guard
            let app = status.tonApp,
            let tonChain = chains.first(where: { $0.ecosystem == .ton })
        else {
            throw ConvenienceError(error: "Missing wallet connect proposal")
        }
        let dApp = createDAppViewModel()

        let requiredNetworks = WalletConnectProposalCellModel.DetailsViewModel(
            title: R.string.localizable.requiredNetworks(preferredLanguages: locale.rLanguages),
            subtitle: tonChain.name,
            icon: RemoteImageViewModel(url: tonChain.icon)
        )

        let walletCellViewModels = createWalletsCellModels(from: wallets, forActiveSession: false)

        let infoCells = [
            WalletConnectProposalCellModel.dAppInfo(dApp),
            WalletConnectProposalCellModel(requiredNetworksViewModel: requiredNetworks)
        ].compactMap { $0 }

        let cells = [infoCells, walletCellViewModels].reduce([], +)

        return WalletConnectProposalViewModel(
            indexPath: nil,
            cells: cells,
            expiryDate: nil
        )
    }
}
