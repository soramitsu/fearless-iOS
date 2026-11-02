import SoraFoundation
import SSFUtils
import UIKit
import SSFModels

final class WalletDetailsPresenter {
    weak var view: WalletDetailsViewProtocol?
    private let interactor: WalletDetailsInteractorInputProtocol
    private let wireframe: WalletDetailsWireframeProtocol
    private let viewModelFactory: WalletDetailsViewModelFactoryProtocol
    private var flow: WalletDetailsFlow
    private let availableExportOptionsProvider = AvailableExportOptionsProvider()

    private var chains: [ChainModel] = []
    private var searchText: String?
    /// Per-chain accounts the wallet keeps stored but does not use at the moment.
    private var storedChainAccounts: [ChainAccountModel] = []
    /// Universal accounts the words alone open in a wallet with a password.
    private var noPasswordAccounts: [UniversalWalletNoPasswordAccount] = []

    init(
        interactor: WalletDetailsInteractorInputProtocol,
        wireframe: WalletDetailsWireframeProtocol,
        viewModelFactory: WalletDetailsViewModelFactoryProtocol,
        flow: WalletDetailsFlow,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.flow = flow
        self.localizationManager = localizationManager
    }
}

extension WalletDetailsPresenter: Localizable {
    func applyLocalization() {
        provideViewModel(chains: chains)
        view?.didReceive(locale: selectedLocale)
    }
}

extension WalletDetailsPresenter: WalletDetailsViewOutputProtocol {
    func didLoad(ui: WalletDetailsViewProtocol) {
        view = ui
        view?.didReceive(locale: selectedLocale)
        interactor.setup()
    }

    func didTapCloseButton() {
        wireframe.dismiss(view: view)
    }

    func didTapExportButton() {
        guard case let .export(wallet, accounts) = flow else {
            return
        }

        wireframe.showExport(
            flow: .multiple(wallet: wallet, accounts: accounts),
            options: availableExportOptionsProvider.getAvailableExportOptions(for: wallet, accountId: nil),
            locale: selectedLocale,
            from: view
        )
    }

    func didReceive(error: Error) {
        guard !wireframe.present(error: error, from: view, locale: selectedLocale) else {
            return
        }

        _ = wireframe.present(
            error: CommonError.undefined,
            from: view,
            locale: selectedLocale
        )
    }

    func showActions(for chain: ChainModel, account: ChainAccountResponse?) {
        let unused = (flow.wallet.unusedChainIds ?? []).contains(chain.chainId)
        let options: [MissingAccountOption?] = [.create, .import, unused ? nil : .skip]

        guard let account = account else {
            guard !UniversalWalletChainAccountSupport.isUniversalWalletChain(chain.chainId) else {
                return
            }
            wireframe.presentAccountOptions(
                from: view,
                locale: selectedLocale,
                options: options.compactMap { $0 },
                uniqueChainModel: UniqueChainModel(
                    meta: flow.wallet,
                    chain: chain
                )
            ) { [weak self] chain in
                self?.interactor.markUnused(chain: chain)
            }
            return
        }

        if UniversalWalletChainAccountSupport.isUniversalWalletChain(chain.chainId) {
            didReceiveExportOptions(
                options: [],
                for: ChainAccountInfo(chain: chain, account: account)
            )
            return
        }

        interactor.getAvailableExportOptions(for: ChainAccountInfo(chain: chain, account: account))
    }

    func searchTextDidChanged(_ text: String?) {
        searchText = text
        provideViewModel(chains: chains)
    }
}

extension WalletDetailsPresenter: WalletDetailsInteractorOutputProtocol {
    func didReceiveExportOptions(options: [ExportOption], for chainAccount: ChainAccountInfo) {
        guard let address = chainAccount.account.toAddress() else {
            return
        }
        let storedAccounts = storedAccountsByAddress(for: chainAccount.chain)
        let noPasswordAccount = noPasswordAccount(for: chainAccount.chain)
        let items: [ChainAction] = createActions(for: chainAccount.chain, address: address)
            + accountSelectionActions(for: chainAccount, storedAddresses: storedAccounts.keys.sorted())
            + (noPasswordAccount == nil ? [] : [.switchToPasswordAccount])
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self,
                  let view = self.view
            else { return }
            let action = items[selectedIndex]
            switch action {
            case .claimCrowdloanRewards:
                break
            case .export:
                self.wireframe.showExport(
                    flow: .single(chain: chainAccount.chain, address: address, wallet: self.flow.wallet),
                    options: options,
                    locale: self.selectedLocale,
                    from: self.view
                )
            case .switchNode:
                self.wireframe.presentNodeSelection(
                    from: self.view,
                    chain: chainAccount.chain
                )
            case .copyAddress:
                UIPasteboard.general.string = address
                let title = R.string.localizable.commonCopied(preferredLanguages: self.selectedLocale.rLanguages)
                self.wireframe.presentSuccessNotification(title, from: self.view)
            case let .subscan(url):
                self.wireframe.present(from: view, url: url)
            case let .polkascan(url):
                self.wireframe.present(from: view, url: url)
            case let .etherscan(url):
                self.wireframe.present(from: view, url: url)
            case let .reefscan(url):
                self.wireframe.present(from: view, url: url)
            case .replace:
                let model = UniqueChainModel(meta: self.flow.wallet, chain: chainAccount.chain)
                let options: [ReplaceChainOption] = ReplaceChainOption.allCases
                self.wireframe.showUniqueChainSourceSelection(
                    from: view,
                    items: options,
                    callback: { [weak self] selectedIndex in
                        let option = options[selectedIndex]
                        switch option {
                        case .create:
                            self?.wireframe.showCreate(uniqueChainModel: model, from: view)
                        case .import:
                            self?.wireframe.showImport(uniqueChainModel: model, from: view)
                        }
                    }
                )
            case let .oklink(url: url):
                self.wireframe.present(from: view, url: url)
            case .useStoredAccount, .useWalletAccount:
                self.confirmAccountSelection(for: action, storedAccounts: storedAccounts, chain: chainAccount.chain)
            case .switchToPasswordAccount:
                if let noPasswordAccount {
                    self.interactor.switchToPasswordAccount(noPasswordAccount)
                }
            }
        }
        wireframe.presentActions(
            from: view,
            items: items,
            chain: chainAccount.chain,
            callback: selectionCallback
        )
    }

    func didReceive(chains: [ChainModel]) {
        self.chains = chains
        provideViewModel(chains: chains)
    }

    func didReceive(updatedFlow: WalletDetailsFlow) {
        flow = updatedFlow
        provideViewModel(chains: chains)
    }

    func didReceive(storedChainAccounts: [ChainAccountModel]) {
        self.storedChainAccounts = storedChainAccounts
        provideViewModel(chains: chains)
    }

    func didReceive(noPasswordAccounts: [UniversalWalletNoPasswordAccount]) {
        self.noPasswordAccounts = noPasswordAccounts
    }

    func didReceive(
        switchOutcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount]
    ) {
        wireframe.present(
            viewModel: UniversalWalletPasswordNotice.outcomes(switchOutcomes, for: accounts, locale: selectedLocale),
            from: view
        )
    }
}

private extension WalletDetailsPresenter {
    /// Nexus shows the Taira key, so it offers the Taira switch.
    func noPasswordAccount(for chain: ChainModel) -> UniversalWalletNoPasswordAccount? {
        guard flow.actionsAvailable, let slot = UniversalWalletSlot(chainId: chain.chainId) else {
            return nil
        }
        return noPasswordAccounts.first { $0.slot == slot }
    }

    func provideViewModel(chains: [ChainModel]) {
        let listedChains = chains.listedForKeyAccess(by: flow.wallet, storedAccounts: storedChainAccounts)
        switch flow {
        case .normal:
            let viewModel = viewModelFactory.buildNormalViewModel(
                flow: flow,
                chains: listedChains,
                chainsWithStoredAccounts: listedChains.filter { !storedAccountsByAddress(for: $0).isEmpty },
                locale: selectedLocale,
                searchText: searchText
            )
            view?.didReceive(state: .normal(viewModel: viewModel))
        case .export:
            let viewModel = viewModelFactory.buildExportViewModel(
                flow: flow,
                chains: listedChains,
                locale: selectedLocale,
                searchText: searchText
            )
            view?.didReceive(state: .export(viewModel: viewModel))
        }
    }

    /// The stored accounts the user can switch to on this chain, by the address each has there.
    func storedAccountsByAddress(for chain: ChainModel) -> [String: ChainAccountModel] {
        guard flow.actionsAvailable, !UniversalWalletChainAccountSupport.isUniversalWalletChain(chain.chainId) else {
            return [:]
        }

        var accounts: [String: ChainAccountModel] = [:]
        for storedAccount in storedChainAccounts {
            if let address = flow.wallet.response(for: storedAccount, request: chain.accountRequest())?.toAddress() {
                accounts[address] = storedAccount
            }
        }

        return accounts
    }

    /// The address the wallet's own account has on this chain, if the wallet has one for it.
    func walletAccountAddress(for chain: ChainModel) -> String? {
        let withoutChainAccounts = flow.wallet.replacingChainAccounts([])
        return withoutChainAccounts.fetch(for: chain.accountRequest())?.toAddress()
    }

    func accountSelectionActions(for chainAccount: ChainAccountInfo, storedAddresses: [String]) -> [ChainAction] {
        var actions: [ChainAction] = storedAddresses.map { .useStoredAccount(address: $0) }

        if
            flow.actionsAvailable,
            chainAccount.account.isChainAccount,
            !UniversalWalletChainAccountSupport.isUniversalWalletChain(chainAccount.chain.chainId),
            walletAccountAddress(for: chainAccount.chain) != nil {
            actions.append(.useWalletAccount)
        }

        return actions
    }

    func confirmAccountSelection(
        for action: ChainAction,
        storedAccounts: [String: ChainAccountModel],
        chain: ChainModel
    ) {
        switch action {
        case let .useStoredAccount(storedAddress):
            guard let storedAccount = storedAccounts[storedAddress] else {
                return
            }
            confirmAccountSelection(
                .chainAccount(accountId: storedAccount.accountId, publicKey: storedAccount.publicKey),
                address: storedAddress,
                chain: chain
            )
        case .useWalletAccount:
            guard let walletAddress = walletAccountAddress(for: chain) else {
                return
            }
            confirmAccountSelection(.walletAccount, address: walletAddress, chain: chain)
        default:
            break
        }
    }

    /// Switching changes the address shown and used on the chain, so it is never done on one tap.
    func confirmAccountSelection(_ selection: ChainAccountSelection, address: String, chain: ChainModel) {
        let languages = selectedLocale.rLanguages
        let confirmAction = SheetAlertPresentableAction(
            title: R.string.localizable.walletChainAccountsSwitchConfirm(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText
        ) { [weak self] in
            self?.interactor.selectChainAccount(selection, chain: chain)
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.walletChainAccountsSwitchTitle(chain.name, preferredLanguages: languages),
            message: R.string.localizable.walletChainAccountsSwitchMessage(
                address, chain.name, preferredLanguages: languages
            ),
            actions: [confirmAction],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: languages),
            icon: R.image.iconWarningBig()
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    func createActions(for chain: ChainModel, address: String) -> [ChainAction] {
        var actions = Self.baseActions(for: chain)
        if let explorers = chain.externalApi?.explorers {
            let explorerActions: [ChainAction] = explorers.compactMap { explorer -> ChainAction? in
                switch explorer.type {
                case .subscan:
                    if explorer.types.contains(.account), let url = explorer.explorerUrl(for: address, type: .account) {
                        return .subscan(url: url)
                    }
                case .polkascan:
                    if explorer.types.contains(.account), let url = explorer.explorerUrl(for: address, type: .account) {
                        return .polkascan(url: url)
                    }
                case .etherscan:
                    if explorer.types.contains(.address), let url = explorer.explorerUrl(for: address, type: .address) {
                        return .etherscan(url: url)
                    }
                case .reef:
                    if explorer.types.contains(.account), let url = explorer.explorerUrl(for: address, type: .account) {
                        return .reefscan(url: url)
                    }
                case .oklink:
                    if explorer.types.contains(.address), let url = explorer.explorerUrl(for: address, type: .address) {
                        return .oklink(url: url)
                    }
                case .unknown:
                    return nil
                }
                return nil
            }
            actions.append(contentsOf: explorerActions)
        }
        return actions
    }
}

extension WalletDetailsPresenter {
    static func baseActions(for chain: ChainModel) -> [ChainAction] {
        if UniversalWalletChainAccountSupport.isUniversalWalletChain(chain.chainId) {
            return [.copyAddress]
        }

        return [.copyAddress, .switchNode, .export, .replace]
    }
}
