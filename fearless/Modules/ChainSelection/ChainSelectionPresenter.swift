import Foundation
import SoraFoundation

final class ChainSelectionPresenter {
    weak var view: ChainSelectionViewProtocol?
    private let wireframe: ChainSelectionWireframeProtocol
    private let interactor: ChainSelectionInteractorInputProtocol
    private let selectedChainId: ChainModel.Id?
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private var chainAssetModels: [ChainAsset] = []
    private var accountInfoResults: [ChainAssetKey: Result<AccountInfo?, Error>] = [:]
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

        let assetInfo = asset.asset.displayInfo

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
        viewModels = chainAssetModels.map { chainAsset in
            let icon: ImageViewModelProtocol? = chainAsset.chain.icon.map { RemoteImageViewModel(url: $0) }
            let title = chainAsset.chain.name
            let isSelected = chainAsset.chain.identifier == selectedChainId
            let balance = extractBalance(for: chainAsset.chain) ?? ""

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

        wireframe.complete(on: view, selecting: chainAssetModels[index])
    }

    func setup() {
        interactor.setup()
    }
}

extension ChainSelectionPresenter: ChainSelectionInteractorOutputProtocol {
    func didReceiveChains(result: Result<[ChainModel], Error>) {
        switch result {
        case let .success(chains):
            chainAssetModels = chains.map(\.chainAssets).reduce([], +)
            updateView()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAssetKey: ChainAssetKey) {
        accountInfoResults[chainAssetKey] = result
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
