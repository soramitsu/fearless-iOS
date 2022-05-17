import Foundation
import SoraFoundation
import Charts

typealias PriceDataUpdated = (priceData: PriceData?, updated: Bool)

final class ChainAccountBalanceListPresenter {
    weak var view: ChainAccountBalanceListViewProtocol?
    let wireframe: ChainAccountBalanceListWireframeProtocol
    let interactor: ChainAccountBalanceListInteractorInputProtocol
    let viewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol

    private var sortedKeys: [String]?
    private var chainModels: [ChainModel] = []

    private var accountInfos: [ChainModel.Id: AccountInfo?] = [:]
    private var prices: [AssetModel.PriceId: PriceDataUpdated] = [:]
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

        updatePrices(for: viewModel.accountViewModels)
    }

    private func updatePrices(for accountViewModels: [ChainAccountBalanceCellViewModel]) {
        let updatedAssets = accountViewModels.map { viewModel -> AssetModel? in
            switch viewModel.priceAttributedString {
            case .normal, .normalAttributed, .stopShimmering:
                return viewModel.asset
            case .updating, .updatingAttributed:
                return nil
            }
        }.compactMap { $0 }

        updatedAssets.forEach {
            prices[$0.chainId]?.updated = false
        }
    }

    private func priceUpdateDidStart() {
        let chainModelsWithPriceId = chainModels.filter { chain in
            !chain.assets.filter { $0.asset.priceId != nil }.isEmpty
        }

        for chain in chainModelsWithPriceId {
            for asset in chain.assets {
                if let priceId = asset.asset.priceId {
                    prices[priceId]?.updated = false
                }
            }
        }
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
        wireframe.showManageAssets(from: view)
    }

    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        if viewModel.chain.isSupported {
            wireframe.showChainAccount(from: view, chain: viewModel.chain, asset: viewModel.asset)
        } else {
            wireframe.presentWarningAlert(from: view, config: WarningAlertConfig.unsupportedChainConfig(with: selectedLocale)) { [weak self] in
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
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id) {
        switch result {
        case let .success(accountInfo):
            accountInfos[chainId] = accountInfo
        case .failure:
            break
        }
        provideViewModel()
    }

    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId) {
        func setOldValue() {
            if let priceData = prices[priceId] {
                let priceDataUpdated = (priceData: priceData.priceData, updated: true)
                prices[priceId] = priceDataUpdated
                provideViewModel()
            } else {
                let priceDataUpdated = (priceData: PriceData?.none, updated: true)
                prices[priceId] = priceDataUpdated
            }
        }

        switch result {
        case let .success(priceDataResult):
            guard let priceDataResult = priceDataResult else {
                setOldValue()
                return
            }
            let priceDataUpdated = (priceData: priceDataResult, updated: true)
            prices[priceId] = priceDataUpdated
        case .failure:
            setOldValue()
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
