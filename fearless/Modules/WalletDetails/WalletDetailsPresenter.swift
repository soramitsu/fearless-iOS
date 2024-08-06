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
        let items: [ChainAction] = createActions(for: chainAccount.chain, address: address)
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
}

private extension WalletDetailsPresenter {
    func provideViewModel(chains: [ChainModel]) {
        switch flow {
        case .normal:
            let viewModel = viewModelFactory.buildNormalViewModel(
                flow: flow,
                chains: chains,
                locale: selectedLocale,
                searchText: searchText
            )
            view?.didReceive(state: .normal(viewModel: viewModel))
        case .export:
            let viewModel = viewModelFactory.buildExportViewModel(
                flow: flow,
                chains: chains,
                locale: selectedLocale,
                searchText: searchText
            )
            view?.didReceive(state: .export(viewModel: viewModel))
        }
    }

    func createActions(for chain: ChainModel, address: String) -> [ChainAction] {
        var actions: [ChainAction] = [.copyAddress, .switchNode, .export, .replace]
        if let explorers = chain.externalApi?.explorers {
            let explorerActions: [ChainAction] = explorers.compactMap {
                switch $0.type {
                case .subscan:
                    if $0.types.contains(.account), let url = $0.explorerUrl(for: address, type: .account) {
                        return .subscan(url: url)
                    }
                case .polkascan:
                    if $0.types.contains(.account), let url = $0.explorerUrl(for: address, type: .account) {
                        return .polkascan(url: url)
                    }
                case .etherscan:
                    if $0.types.contains(.address), let url = $0.explorerUrl(for: address, type: .address) {
                        return .etherscan(url: url)
                    }
                case .reef:
                    if $0.types.contains(.account), let url = $0.explorerUrl(for: address, type: .account) {
                        return .polkascan(url: url)
                    }
                case .unknown:
                    return nil
                case .oklink:
                    if $0.types.contains(.account), let url = $0.explorerUrl(for: address, type: .account) {
                        return .oklink(url: url)
                    }
                }
                return nil
            }
            actions.append(contentsOf: explorerActions)
        }
        return actions
    }
}
