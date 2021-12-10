import Foundation
import SoraFoundation

final class AssetSelectionPresenter {
    weak var view: ChainSelectionViewProtocol?
    let wireframe: AssetSelectionWireframeProtocol
    let interactor: ChainSelectionInteractorInputProtocol
    let selectedChainAssetId: ChainAssetId?
    let assetFilter: AssetSelectionFilter
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private var assets: [(ChainModel.Id, AssetModel)] = []
    private var chains: [ChainModel.Id: ChainModel] = [:]

    private var accountInfoResults: [ChainModel.Id: Result<AccountInfo?, Error>] = [:]

    private var viewModels: [SelectableIconDetailsListViewModel] = []

    init(
        interactor: ChainSelectionInteractorInputProtocol,
        wireframe: AssetSelectionWireframeProtocol,
        assetFilter: @escaping AssetSelectionFilter,
        selectedChainAssetId: ChainAssetId?,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.assetFilter = assetFilter
        self.selectedChainAssetId = selectedChainAssetId
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.localizationManager = localizationManager
    }

    private func extractBalance(for chain: ChainModel, asset: AssetModel) -> String? {
        guard
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
        viewModels = assets.compactMap { assetPair in
            guard let chain = chains[assetPair.0] else {
                return nil
            }

            let asset = assetPair.1

            let icon = RemoteImageViewModel(url: asset.icon ?? chain.icon)
            let title = asset.name ?? chain.name
            let isSelected = selectedChainAssetId?.assetId == asset.assetId &&
                selectedChainAssetId?.chainId == chain.chainId
            let balance = extractBalance(for: chain, asset: asset) ?? ""

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

extension AssetSelectionPresenter: ChainSelectionPresenterProtocol {
    var numberOfItems: Int {
        viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        let chainId = assets[index].0
        let asset = assets[index].1

        guard let view = view, let chain = chains[chainId] else {
            return
        }

        wireframe.complete(on: view, selecting: ChainAsset(chain: chain, asset: asset))
    }

    func setup() {
        interactor.setup()
    }
}

extension AssetSelectionPresenter: ChainSelectionInteractorOutputProtocol {
    func didReceiveChains(result: Result<[ChainModel], Error>) {
        switch result {
        case let .success(chains):
            self.chains = chains.reduce(into: [:]) { result, item in
                result[item.chainId] = item
            }

            assets = chains.reduce(into: []) { result, item in
                let assets: [(ChainModel.Id, AssetModel)] = item.assets.compactMap { asset in
                    if assetFilter(item, asset) {
                        return (item.chainId, asset)
                    } else {
                        return nil
                    }
                }

                result.append(contentsOf: assets)
            }

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

extension AssetSelectionPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
