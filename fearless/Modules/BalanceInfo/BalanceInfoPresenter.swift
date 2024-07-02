import Foundation
import SoraFoundation
import BigInt

final class BalanceInfoPresenter {
    // MARK: Private properties

    private weak var view: BalanceInfoViewInput?
    private let router: BalanceInfoRouterInput
    private let interactor: BalanceInfoInteractorInput
    private let eventCenter: EventCenterProtocol

    private let balanceInfoViewModelFactoryProtocol: BalanceInfoViewModelFactoryProtocol
    private let logger: LoggerProtocol

    private var balances: WalletBalanceInfos = [:]
    private var minimumBalance: BigUInt?
    private var balanceLocks: BalanceLocks?

    // MARK: - Constructors

    init(
        balanceInfoViewModelFactoryProtocol: BalanceInfoViewModelFactoryProtocol,
        interactor: BalanceInfoInteractorInput,
        router: BalanceInfoRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.balanceInfoViewModelFactoryProtocol = balanceInfoViewModelFactoryProtocol
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.eventCenter = eventCenter
        self.localizationManager = localizationManager

        eventCenter.add(observer: self)
    }

    // MARK: - Private methods

    private func buildBalance() {
        let viewModel = balanceInfoViewModelFactoryProtocol.buildBalanceInfo(
            with: interactor.balanceInfoType,
            balances: balances,
            infoButtonEnabled: createBalanceContext() != nil,
            locale: selectedLocale
        )

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveViewModel(viewModel)
        }
    }

    private func createBalanceContext() -> BalanceContext? {
        guard case let .chainAsset(wallet, chainAsset) = interactor.balanceInfoType,
              let balance = balances[wallet.metaId] else {
            return nil
        }
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
           let accountInfo = balance.accountInfos[chainAsset.uniqueKey(accountId: accountId)],
           let info = accountInfo,
           let free = Decimal.fromSubstratePerbill(value: info.data.free),
           let reserved = Decimal.fromSubstratePerbill(value: info.data.reserved),
           let frozen = Decimal.fromSubstratePerbill(value: info.data.frozen),
           let minBalance = minimumBalance,
           let decimalMinBalance = Decimal.fromSubstratePerbill(value: minBalance),
           let locks = balanceLocks {
            var price: Decimal = 0
            let priceData = balance.prices.first(where: { $0.priceId == chainAsset.asset.priceId })
            if let data = priceData, let decimalPrice = Decimal(string: data.price) {
                price = decimalPrice
            }
            return BalanceContext(
                free: free,
                reserved: reserved,
                frozen: frozen,
                price: price,
                priceChange: priceData?.fiatDayChange ?? 0,
                minimalBalance: decimalMinBalance,
                balanceLocks: locks
            )
        }
        return nil
    }
}

// MARK: - BalanceInfoViewOutput

extension BalanceInfoPresenter: BalanceInfoViewOutput {
    func didLoad(view: BalanceInfoViewInput) {
        self.view = view
        interactor.setup(with: self)
        view.didReceiveViewModel(nil)
    }
}

// MARK: - BalanceInfoInteractorOutput

extension BalanceInfoPresenter: BalanceInfoInteractorOutput {
    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult) {
        switch result {
        case let .success(balances):
            self.balances = balances
            buildBalance()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance
        case let .failure(error):
            logger.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceiveBalanceLocks(result: Result<BalanceLocks?, Error>) {
        switch result {
        case let .success(balanceLocks):
            self.balanceLocks = balanceLocks
        case let .failure(error):
            logger.error("Did receive balance locks error: \(error)")
        }
    }
}

// MARK: - Localizable

extension BalanceInfoPresenter: Localizable {
    func applyLocalization() {}
}

extension BalanceInfoPresenter: BalanceInfoModuleInput {
    func replace(infoType: BalanceInfoType) {
        interactor.balanceInfoType = infoType
        interactor.fetchBalanceInfo()
    }
}

extension BalanceInfoPresenter: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        switch interactor.balanceInfoType {
        case let .chainAsset(_, chainAsset):
            let newType = BalanceInfoType.chainAsset(wallet: event.account, chainAsset: chainAsset)
            interactor.balanceInfoType = newType
            interactor.fetchBalanceInfo()

        case .wallet:
            let newType = BalanceInfoType.wallet(wallet: event.account)
            interactor.balanceInfoType = newType
            interactor.fetchBalanceInfo()
        case let .chainAssets(chainAssets, _):
            let newType = BalanceInfoType.chainAssets(chainAssets: chainAssets, wallet: event.account)
            interactor.balanceInfoType = newType
            interactor.fetchBalanceInfo()
        case .networkManagement:
            let newType = BalanceInfoType.networkManagement(wallet: event.account)
            interactor.balanceInfoType = newType
            interactor.fetchBalanceInfo()
        }
    }
}
