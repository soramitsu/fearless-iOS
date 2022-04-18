import Foundation
import SoraFoundation
import Charts

final class ChainAccountBalanceListPresenter {
    weak var view: ChainAccountBalanceListViewProtocol?
    let wireframe: ChainAccountBalanceListWireframeProtocol
    let interactor: ChainAccountBalanceListInteractorInputProtocol
    let viewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol

    private var sortedKeys: [String]?
    private var chainModels: [ChainModel] = []

    private var accountInfos: [ChainModel.Id: AccountInfo] = [:]
    private var prices: [AssetModel.PriceId: PriceData] = [:]
    private var viewModels: [ChainAccountBalanceCellViewModel] = []
    private var selectedMetaAccount: MetaAccountModel?

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
}

extension ChainAccountBalanceListPresenter: ChainAccountBalanceListPresenterProtocol {
    func setup() {
        interactor.setup()

        view?.didReceive(locale: selectedLocale)
    }

    func didPullToRefreshOnAssetsTable() {
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
}

extension ChainAccountBalanceListPresenter: ChainAccountBalanceListInteractorOutputProtocol {
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
        accountInfos[chainId] = try? result.get()
        provideViewModel()
    }

    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId) {
        if prices[priceId] != nil, case let .success(priceData) = result, priceData != nil {
            prices[priceId] = try? result.get()
        } else if prices[priceId] == nil {
            prices[priceId] = try? result.get()
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
}

extension ChainAccountBalanceListPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)

        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
