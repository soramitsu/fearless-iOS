import Foundation
import SoraFoundation

final class ChainSelectionPresenter {
    weak var view: ChainSelectionViewProtocol?
    let wireframe: ChainSelectionWireframeProtocol
    let interactor: ChainSelectionInteractorInputProtocol
    let selectedChainId: ChainModel.Id?
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private var chainModels: [ChainModel] = []

    private var accountInfoResults: [ChainModel.Id: Result<AccountInfo?, Error>] = [:]

    private var viewModels: [SelectableIconDetailsListViewModel] = []

    init(
        interactor: ChainSelectionInteractorInputProtocol,
        wireframe: ChainSelectionWireframeProtocol,
        selectedChainId: ChainModel.Id?,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedChainId = selectedChainId
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.localizationManager = localizationManager
    }

    private func extractBalance(for chain: ChainModel) -> String? {
        guard
            let asset = chain.utilityAssets().first,
            let accountInfoResult = accountInfoResults[chain.chainId],
            case let .success(accountInfo) = accountInfoResult else {
            return nil
        }

        let assetInfo = asset.displayInfo

        let maybeBalance: Decimal?

        if let accountInfo = accountInfo {
            maybeBalance = Decimal.fromSubstrateAmount(
                accountInfo.data.available,
                precision: assetInfo.assetPrecision
            )
        } else {
            maybeBalance = 0.0
        }

        guard let balance = maybeBalance else {
            return nil
        }

        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetInfo)
            .value(for: selectedLocale)

        return tokenFormatter.stringFromDecimal(balance)
    }

    private func updateView() {
        viewModels = chainModels.map { chainModel in
            let icon = RemoteImageViewModel(url: chainModel.icon)
            let title = chainModel.name
            let isSelected = chainModel.identifier == selectedChainId
            let balance = extractBalance(for: chainModel) ?? ""

            return SelectableIconDetailsListViewModel(
                title: title,
                subtitle: balance,
                icon: icon,
                isSelected: isSelected
            )
        }

        view?.didReload()
    }
}

extension ChainSelectionPresenter: ChainSelectionPresenterProtocol {
    var numberOfItems: Int {
        viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        guard let view = view else {
            return
        }

        wireframe.complete(on: view, selecting: chainModels[index])
    }

    func setup() {
        interactor.setup()
    }
}

extension ChainSelectionPresenter: ChainSelectionInteractorOutputProtocol {
    func didReceiveChains(result: Result<[ChainModel], Error>) {
        switch result {
        case let .success(chains):
            chainModels = chains
            updateView()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id) {
        accountInfoResults[chainId] = result
        updateView()
    }
}

extension ChainSelectionPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
