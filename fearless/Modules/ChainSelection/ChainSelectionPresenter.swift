import Foundation
import SoraFoundation

final class ChainSelectionPresenter {
    weak var view: ChainSelectionViewProtocol?
    private let wireframe: ChainSelectionWireframeProtocol
    private let interactor: ChainSelectionInteractorInputProtocol
    private let selectedChainId: ChainModel.Id?
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let selectedMetaAccount: MetaAccountModel
    private let includeAllNetworksCell: Bool
    private let showBalances: Bool

    private var chainModels: [ChainModel] = []
    private var accountInfoResults: [ChainAssetKey: Result<AccountInfo?, Error>] = [:]
    private var viewModels: [SelectableIconDetailsListViewModel] = []

    init(
        interactor: ChainSelectionInteractorInputProtocol,
        wireframe: ChainSelectionWireframeProtocol,
        selectedChainId: ChainModel.Id?,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        includeAllNetworksCell: Bool,
        showBalances: Bool,
        selectedMetaAccount: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedChainId = selectedChainId
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.includeAllNetworksCell = includeAllNetworksCell
        self.showBalances = showBalances
        self.selectedMetaAccount = selectedMetaAccount
        self.localizationManager = localizationManager
    }

    private func extractBalance(for chain: ChainModel) -> String? {
        guard
            showBalances,
            let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId
        else {
            return nil
        }

        guard let chainAssetWithBalance = chain.utilityChainAssets().first(where: { chainAsset in
            let accountInfoResult = accountInfoResults[chainAsset.uniqueKey(accountId: accountId)]

            guard case let .success(accountInfo) = accountInfoResult else {
                return false
            }
            return accountInfo != nil
        }) else {
            return nil
        }

        let assetInfo = chainAssetWithBalance.asset.displayInfo
        let accountInfoResult = accountInfoResults[chainAssetWithBalance.uniqueKey(accountId: accountId)]
        guard case let .success(accountInfo) = accountInfoResult else {
            return nil
        }
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
        viewModels = chainModels.filter { selectedMetaAccount.fetch(for: $0.accountRequest()) != nil }.map { chain in
            let icon: ImageViewModelProtocol? = chain.icon.map { RemoteImageViewModel(url: $0) }
            let title = chain.name
            let isSelected = chain.identifier == selectedChainId
            let balance = extractBalance(for: chain) ?? ""

            return SelectableIconDetailsListViewModel(
                title: title,
                subtitle: balance,
                icon: icon,
                isSelected: isSelected,
                identifier: chain.chainId
            )
        }

        if includeAllNetworksCell {
            let allNetworksViewModel = SelectableIconDetailsListViewModel(
                title: R.string.localizable.chainSelectionAllNetworks(preferredLanguages: selectedLocale.rLanguages),
                subtitle: nil,
                icon: nil,
                isSelected: selectedChainId == nil,
                identifier: nil
            )
            viewModels.insert(allNetworksViewModel, at: 0)
        }

        DispatchQueue.main.async {
            self.view?.didReload()
        }
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

        let index = includeAllNetworksCell ? index - 1 : index
        wireframe.complete(on: view, selecting: chainModels[safe: index])
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
