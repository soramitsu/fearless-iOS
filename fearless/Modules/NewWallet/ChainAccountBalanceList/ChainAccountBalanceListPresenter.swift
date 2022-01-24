import Foundation
import SoraFoundation
import Charts

final class ChainAccountBalanceListPresenter {
    weak var view: ChainAccountBalanceListViewProtocol?
    let wireframe: ChainAccountBalanceListWireframeProtocol
    let interactor: ChainAccountBalanceListInteractorInputProtocol
    let viewModelFactory: ChainAccountBalanceListViewModelFactoryProtocol

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
        let viewModel = viewModelFactory.buildChainAccountBalanceListViewModel(
            selectedMetaAccount: selectedMetaAccount,
            chains: chainModels,
            locale: selectedLocale,
            accountInfos: accountInfos,
            prices: prices
        )

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension ChainAccountBalanceListPresenter: ChainAccountBalanceListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didPullToRefreshOnAssetsTable() {
        interactor.refresh()
    }

    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        guard let chain = chainModels.first(where: { $0.assets.map(\.asset).contains(viewModel.asset) }) else {
            return
        }

        wireframe.showChainAccount(from: view, chain: chain, asset: viewModel.asset)
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
    }

    func didTapAccountButton() {
        wireframe.showWalletSelection(from: view)
    }
}

extension ChainAccountBalanceListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
