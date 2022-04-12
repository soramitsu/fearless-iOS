import SoraFoundation
import FearlessUtils
import UIKit
final class WalletDetailsPresenter {
    weak var view: WalletDetailsViewProtocol?
    private let interactor: WalletDetailsInteractorInputProtocol
    private let wireframe: WalletDetailsWireframeProtocol
    private let viewModelFactory: WalletDetailsViewModelFactoryProtocol
    private var flow: WalletDetailsFlow
    private let availableExportOptionsProvider = AvailableExportOptionsProvider()

    private var chainAccounts: [ChainAccountInfo] = []
    private lazy var inputViewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        inputHandling.changeValue(to: flow.wallet.name)
        return InputViewModel(
            inputHandler: inputHandling,
            title: R.string.localizable.usernameSetupChooseTitle(preferredLanguages: selectedLocale.rLanguages)
        )
    }()

    private lazy var iconGenerator = {
        PolkadotIconGenerator()
    }

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
        provideViewModel(chainAccounts: chainAccounts)
    }
}

extension WalletDetailsPresenter: WalletDetailsViewOutputProtocol {
    func didLoad(ui: WalletDetailsViewProtocol) {
        view = ui
        view?.setInput(viewModel: inputViewModel)
        interactor.setup()
    }

    func updateData() {
//        TODO: Will required when add chain acounts changes
    }

    func didTapCloseButton() {
        if let view = self.view {
            wireframe.close(view)
        }
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

    func willDisappear() {
        if inputViewModel.inputHandler.value != flow.wallet.name {
            interactor.update(walletName: inputViewModel.inputHandler.value)
        }
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

    func showActions(for chainAccount: ChainAccountInfo) {
        guard let address = chainAccount.account.toAddress() else {
            return
        }

        interactor.getAvailableExportOptions(for: chainAccount, address: address)
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
            case .export:
                self.wireframe.showExport(
                    flow: .single(chain: chainAccount.chain, address: address),
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
            }
        }
        wireframe.presentAcions(
            from: view,
            items: items,
            callback: selectionCallback
        )
    }

    func didReceive(chainAccounts: [ChainAccountInfo]) {
        self.chainAccounts = chainAccounts
        provideViewModel(chainAccounts: chainAccounts)
    }
}

private extension WalletDetailsPresenter {
    func provideViewModel(chainAccounts: [ChainAccountInfo]) {
        switch flow {
        case .normal:
            let viewModel = viewModelFactory.buildNormalViewModel(
                flow: flow,
                chainAccounts: chainAccounts,
                locale: selectedLocale
            )
            view?.didReceive(state: .normal(viewModel: viewModel))
        case .export:
            let viewModel = viewModelFactory.buildExportViewModel(
                flow: flow,
                chainAccounts: chainAccounts,
                locale: selectedLocale
            )
            view?.didReceive(state: .export(viewModel: viewModel))
        }
    }

    func createActions(for chain: ChainModel, address: String) -> [ChainAction] {
        var actions: [ChainAction] = [.copyAddress, .switchNode, .export]
        if let polkascanUrl = chain.polkascanAddressURL(address) {
            actions.append(.polkascan(url: polkascanUrl))
        }
        if let subscanUrl = chain.subscanAddressURL(address) {
            actions.append(.subscan(url: subscanUrl))
        }
        return actions
    }
}
