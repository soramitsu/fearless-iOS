import Foundation
import SoraFoundation
import Charts

typealias PriceDataUpdated = (pricesData: [PriceData], updated: Bool)

final class ChainAccountBalanceListPresenter {
    weak var view: ChainAccountBalanceListViewProtocol?
    let wireframe: ChainAccountBalanceListWireframeProtocol
    let interactor: ChainAccountBalanceListInteractorInputProtocol
    let viewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol

    private var sortedKeys: [String]?
    private var chainModels: [ChainModel] = []

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var prices: PriceDataUpdated = ([], false)
    private var viewModels: [ChainAccountBalanceCellViewModel] = []
    private var selectedMetaAccount: MetaAccountModel?
    private var selectedCurrency: Currency?

    init(
        interactor: ChainAccountBalanceListInteractorInputProtocol,
        wireframe: ChainAccountBalanceListWireframeProtocol,
        viewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        guard let selectedMetaAccount = selectedMetaAccount else {
            return
        }

        let viewModel = viewModelFactory.buildChainAccountBalanceListViewModel(
            selectedMetaAccount: selectedMetaAccount,
            chains: chainModels,
            locale: selectedLocale,
            accountInfos: accountInfos,
            prices: prices,
            sortedKeys: sortedKeys
        )

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }

    private func priceUpdateDidStart() {
        prices.updated = false
    }
}

extension ChainAccountBalanceListPresenter: ChainAccountBalanceListPresenterProtocol {
    func setup() {
        interactor.setup()

        view?.didReceive(locale: selectedLocale)
    }

    func didPullToRefreshOnAssetsTable() {
        priceUpdateDidStart()
        provideViewModel()
        interactor.refresh()
    }

    func didTapManageAssetsButton() {
        wireframe.showManageAssets(from: view, chainModels: chainModels)
    }

    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        if viewModel.chain.isSupported {
            wireframe.showChainAccount(from: view, chain: viewModel.chain, asset: viewModel.asset)
        } else {
            wireframe.presentWarningAlert(
                from: view,
                config: WarningAlertConfig.unsupportedChainConfig(with: selectedLocale)
            ) { [weak self] in
                self?.wireframe.showAppstoreUpdatePage()
            }
        }
    }

    func didTapTotalBalanceLabel() {
        interactor.fetchFiats()
    }
}

extension ChainAccountBalanceListPresenter: ChainAccountBalanceListInteractorOutputProtocol {
    func didReceiveSupportedCurrencys(_ supportedCurrencys: Result<[Currency], Error>) {
        switch supportedCurrencys {
        case let .success(supportedCurrencys):

            let selectionCallback: ModalPickerSelectionCallback = { [weak self, supportedCurrencys] selectedIndex in
                guard let strongSelf = self else { return }

                strongSelf.priceUpdateDidStart()
                strongSelf.provideViewModel()

                var selectedCurrency = supportedCurrencys[selectedIndex]
                selectedCurrency.isSelected = true
                strongSelf.interactor.didReceive(currency: selectedCurrency)
            }

            wireframe.presentSelectCurrency(
                from: view,
                supportedCurrencys: supportedCurrencys,
                selectedCurrency: selectedCurrency ?? Currency.defaultCurrency(),
                callback: selectionCallback
            )
        case let .failure(error):
            wireframe.present(error: error, from: view, locale: localizationManager?.selectedLocale)
        }
    }

    func didReceiveChains(result: Result<[ChainModel], Error>) {
        switch result {
        case let .success(chains):
            chainModels = chains
            provideViewModel()
        case let .failure(error):
            // TODO: Consider more cool UX when error received when loading chains/assets
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountId = selectedMetaAccount?.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)
            accountInfos[key] = accountInfo
        case let .failure(error):
            wireframe.present(error: error, from: view, locale: selectedLocale)
        }
        provideViewModel()
    }

    func didRecieceAccountInfos(_ accountInfo: [ChainAssetKey: AccountInfo?]) {
        accountInfos = accountInfo
        provideViewModel()
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(priceDataResult):
            let priceDataUpdated = (pricesData: priceDataResult, updated: true)
            prices = priceDataUpdated
        case let .failure(error):
            wireframe.present(error: error, from: view, locale: selectedLocale)
        }

        provideViewModel()
    }

    func didReceiveSelectedAccount(_ account: MetaAccountModel) {
        selectedMetaAccount = account

        sortedKeys = account.assetKeysOrder
        provideViewModel()
    }

    func didTapAccountButton() {
        wireframe.showWalletSelection(from: view)
    }

    func didRecieveSelectedCurrency(_ selectedCurrency: Currency) {
        self.selectedCurrency = selectedCurrency
        priceUpdateDidStart()
        provideViewModel()
    }
}

extension ChainAccountBalanceListPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)

        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
