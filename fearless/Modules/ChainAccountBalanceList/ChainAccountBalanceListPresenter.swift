import Foundation
import SoraFoundation
import Charts

final class ChainAccountBalanceListPresenter {
    weak var view: ChainAccountBalanceListViewProtocol?
    let wireframe: ChainAccountBalanceListWireframeProtocol
    let interactor: ChainAccountBalanceListInteractorInputProtocol
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private var chainModels: [ChainModel] = []

    private var accountInfoResults: [ChainModel.Id: Result<AccountInfo?, Error>] = [:]
    private var priceResults: [AssetModel.PriceId: Result<PriceData?, Error>] = [:]
    private var viewModels: [ChainAccountBalanceCellViewModel] = []
    private var selectedMetaAccount: MetaAccountModel?

    init(
        interactor: ChainAccountBalanceListInteractorInputProtocol,
        wireframe: ChainAccountBalanceListWireframeProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.localizationManager = localizationManager
    }

    private func getBalance(for chain: ChainModel) -> String? {
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

        return balance.stringWithPointSeparator
    }

    private func getPriceAttributedString(for asset: AssetModel) -> NSAttributedString? {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: selectedLocale)

        guard let priceId = asset.priceId, let priceData = try? priceResults[priceId]?.get(),
              let priceDecimal = Decimal(string: priceData.price) else {
            return nil
        }

        let changeString: String = priceData.usdDayChange.map {
            let percentValue = $0 / 100
            return percentValue.percentString() ?? ""
        } ?? ""

        let priceString: String = usdTokenFormatterValue.stringFromDecimal(priceDecimal) ?? ""

        let priceWithChangeString = [priceString, changeString].joined(separator: " ")

        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = (priceData.usdDayChange ?? 0) > 0 ? R.color.colorGreen() : R.color.colorRed()

        if let color = color {
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: color],
                range: NSRange(
                    location: priceString.count + 1,
                    length: changeString.count
                )
            )
        }

        return priceWithChangeAttributed
    }

    private func getUsdBalanceString(
        for asset: AssetModel,
        chain: ChainModel
    ) -> String? {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: selectedLocale)

        let balance = getBalance(for: chain) ?? ""

        guard let priceId = asset.priceId,
              let priceData = try? priceResults[priceId]?.get(),
              let priceDecimal = Decimal(string: priceData.price),
              let balanceDecimal = Decimal(string: balance) else {
            return nil
        }

        let totalBalanceDecimal = priceDecimal * balanceDecimal

        return usdTokenFormatterValue.stringFromDecimal(totalBalanceDecimal)
    }

    private func provideViewModel() {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: selectedLocale)

        let totalWalletBalance: Decimal = chainModels.compactMap { chainModel in

            chainModel.assets.compactMap {
                let balance = getBalance(for: chainModel) ?? ""

                guard let priceId = $0.priceId,
                      let priceData = try? priceResults[priceId]?.get(),
                      let priceDecimal = Decimal(string: priceData.price),
                      let balanceDecimal = Decimal(string: balance) else {
                    return nil
                }

                return priceDecimal * balanceDecimal
            }.reduce(0, +)
        }.reduce(0, +)

        viewModels = chainModels.map { chainModel in

            chainModel.assets.compactMap {
                let icon = RemoteImageViewModel(url: chainModel.icon)
                let title = chainModel.name
                let balance = getBalance(for: chainModel) ?? ""

                return ChainAccountBalanceCellViewModel(
                    chainName: title,
                    assetInfo: $0.displayInfo(with: chainModel.icon),
                    imageViewModel: icon,
                    balanceString: balance,
                    priceAttributedString: getPriceAttributedString(for: $0),
                    totalAmountString: getUsdBalanceString(for: $0, chain: chainModel)
                )
            }

        }.reduce([], +)

        let viewModel = ChainAccountBalanceListViewModel(
            accountName: selectedMetaAccount?.name,
            balance: usdTokenFormatterValue.stringFromDecimal(totalWalletBalance),
            accountViewModels: viewModels
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

    func didSelectViewModel(_: ChainAccountBalanceCellViewModel) {}
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
        accountInfoResults[chainId] = result
        provideViewModel()
    }

    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId) {
        if priceResults[priceId] != nil, case let .success(priceData) = result, priceData != nil {
            priceResults[priceId] = result
        } else if priceResults[priceId] == nil {
            priceResults[priceId] = result
        }

        provideViewModel()
    }

    func didReceiveSelectedAccount(_ account: MetaAccountModel) {
        selectedMetaAccount = account
    }
}

extension ChainAccountBalanceListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
