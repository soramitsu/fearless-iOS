import Foundation
import SoraFoundation
import BigInt

final class ChainAccountPresenter {
    weak var view: ChainAccountViewProtocol?
    let wireframe: ChainAccountWireframeProtocol
    let interactor: ChainAccountInteractorInputProtocol
    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let logger: LoggerProtocol
    var chainAsset: ChainAsset {
        interactor.chainAsset
    }

    let wallet: MetaAccountModel
    weak var moduleOutput: ChainAccountModuleOutput?
    private let balanceInfoModule: BalanceInfoModuleInput

    private lazy var rampProvider = RampProvider()
    private lazy var moonpayProvider: PurchaseProviderProtocol = {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let moonpaySecretKeyData = Data(MoonPayKeys.secretKey.utf8)
        return MoonpayProviderFactory().createProvider(
            with: moonpaySecretKeyData,
            apiKey: config.moonPayApiKey
        )
    }()

    init(
        interactor: ChainAccountInteractorInputProtocol,
        wireframe: ChainAccountWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        logger: LoggerProtocol,
        wallet: MetaAccountModel,
        moduleOutput: ChainAccountModuleOutput?,
        balanceInfoModule: BalanceInfoModuleInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.wallet = wallet
        self.moduleOutput = moduleOutput
        self.balanceInfoModule = balanceInfoModule
        self.localizationManager = localizationManager
    }

    func provideViewModel() {
        let chainAccountViewModel = viewModelFactory.buildChainAccountViewModel(
            chainAsset: chainAsset,
            wallet: wallet
        )

        DispatchQueue.main.async {
            self.view?.didReceiveState(.loaded(chainAccountViewModel))
        }
    }
}

extension ChainAccountPresenter: ChainAccountModuleInput {}

private extension ChainAccountPresenter {
    func getPurchaseActions() -> [PurchaseAction] {
        var actions: [PurchaseAction] = []

        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            let allAssets = Array(chainAsset.chain.assets)
            let chainAssetModel = allAssets.first(where: { $0.assetId == chainAsset.asset.id })

            var availableProviders: [PurchaseProviderProtocol] = []
            chainAssetModel?.purchaseProviders?.compactMap { $0 }.forEach {
                switch $0 {
                case .moonpay:
                    availableProviders.append(moonpayProvider)
                case .ramp:
                    availableProviders.append(rampProvider)
                }
            }

            let providersAggregator = PurchaseAggregator(providers: availableProviders)
            actions = providersAggregator.buildPurchaseActions(asset: chainAsset.asset, address: address)
        }
        return actions
    }
}

extension ChainAccountPresenter: ChainAccountPresenterProtocol {
    func addressDidCopied() {
        wireframe.presentStatus(
            with: AddressCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }

    func setup() {
        interactor.setup()
        provideViewModel()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapSendButton() {
        wireframe.presentSendFlow(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func didTapReceiveButton() {
        wireframe.presentReceiveFlow(
            from: view,
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            wallet: wallet
        )
    }

    func didTapBuyButton() {
        wireframe.presentBuyFlow(
            from: view,
            items: getPurchaseActions(),
            delegate: self
        )
    }

    func didTapOptionsButton() {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }
        interactor.getAvailableExportOptions(for: address)
    }

    func didTapSelectNetwork() {
        wireframe.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: chainAsset.chain.chainId,
            chainModels: interactor.availableChainAssets.map(\.chain),
            delegate: self
        )
    }
}

extension ChainAccountPresenter: ChainAccountInteractorOutputProtocol {
    func didReceiveExportOptions(options: [ExportOption]) {
        let items: [ChainAction] = [.export, .switchNode, .replace]
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self else { return }
            let action = items[selectedIndex]
            switch action {
            case .export:
                guard let address =
                    self.wallet.fetch(for: self.chainAsset.chain.accountRequest())?.toAddress()
                else { return }
                self.wireframe.showExport(
                    for: address,
                    chain: self.chainAsset.chain,
                    options: options,
                    locale: self.selectedLocale,
                    wallet: self.wallet,
                    from: self.view
                )
            case .switchNode:
                self.wireframe.presentNodeSelection(
                    from: self.view,
                    chain: self.chainAsset.chain
                )
            case .replace:
                let model = UniqueChainModel(meta: self.wallet, chain: self.chainAsset.chain)
                let options: [ReplaceChainOption] = ReplaceChainOption.allCases
                self.wireframe.showUniqueChainSourceSelection(
                    from: self.view,
                    items: options,
                    callback: { [weak self] selectedIndex in
                        let option = options[selectedIndex]
                        switch option {
                        case .create:
                            self?.wireframe.showCreate(uniqueChainModel: model, from: self?.view)
                        case .import:
                            self?.wireframe.showImport(uniqueChainModel: model, from: self?.view)
                        }
                    }
                )
            default:
                break
            }
        }

        wireframe.presentChainActionsFlow(
            from: view,
            items: items,
            chain: chainAsset.chain,
            callback: selectionCallback
        )
    }

    func didUpdate(chainAsset: ChainAsset) {
        provideViewModel()
        balanceInfoModule.replace(infoType: .chainAsset(
            wallet: wallet,
            chainAsset: chainAsset
        ))
    }
}

extension ChainAccountPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension ChainAccountPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        wireframe.presentPurchaseWebView(from: view, action: getPurchaseActions()[index])
    }
}

extension ChainAccountPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?
    ) {
        guard let chain = chain else {
            return
        }
        interactor.update(chain: chain)
    }
}
