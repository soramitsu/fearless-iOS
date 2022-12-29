import Foundation
import SoraFoundation

final class AssetSelectionPresenter {
    weak var view: ChainSelectionViewProtocol?
    let wireframe: AssetSelectionWireframeProtocol
    let interactor: ChainSelectionInteractorInputProtocol
    let selectedChainAsset: ChainAsset?
    let assetFilter: AssetSelectionFilter
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let selectedMetaAccount: MetaAccountModel
    let type: AssetSelectionStakingType

    private var assets: [(ChainModel.Id, AssetModel)] = []
    private var chains: [ChainModel.Id: ChainModel] = [:]

    private var accountInfoResults: [ChainAssetKey: Result<AccountInfo?, Error>] = [:]

    private var viewModels: [SelectableIconDetailsListViewModel] = []

    init(
        interactor: ChainSelectionInteractorInputProtocol,
        wireframe: AssetSelectionWireframeProtocol,
        assetFilter: @escaping AssetSelectionFilter,
        type: AssetSelectionStakingType,
        selectedMetaAccount: MetaAccountModel,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.assetFilter = assetFilter
        selectedChainAsset = type.chainAsset
        self.selectedMetaAccount = selectedMetaAccount
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.type = type
        self.localizationManager = localizationManager
    }

    private func extractBalance(for chainAsset: ChainAsset) -> String? {
        guard
            let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            let accountInfoResult = accountInfoResults[chainAsset.uniqueKey(accountId: accountId)],
            case let .success(accountInfo) = accountInfoResult else {
            return nil
        }

        let assetInfo = chainAsset.asset.displayInfo

        let maybeBalance: Decimal?

        if let accountInfo = accountInfo {
            maybeBalance = Decimal.fromSubstrateAmount(
                accountInfo.data.free,
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

            let icon = (asset.icon ?? chain.icon).map { RemoteImageViewModel(url: $0) }
            let title = chain.name
            let isSelected = selectedChainAsset?.asset.id == asset.id &&
                selectedChainAsset?.chain.chainId == chain.chainId
            let balance = extractBalance(for: ChainAsset(chain: chain, asset: asset)) ?? ""

            return SelectableIconDetailsListViewModel(
                title: title,
                subtitle: balance,
                icon: icon,
                isSelected: isSelected,
                identifier: chain.chainId
            )
        }

        DispatchQueue.main.async {
            self.view?.didReload()
        }
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

        wireframe.complete(on: view, selecting: ChainAsset(chain: chain, asset: asset), context: nil)
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
                    if assetFilter(asset), selectedMetaAccount.fetch(for: item.accountRequest()) != nil {
                        return (item.chainId, asset.asset)
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

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAssetKey: ChainAssetKey) {
        accountInfoResults[chainAssetKey] = result
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
