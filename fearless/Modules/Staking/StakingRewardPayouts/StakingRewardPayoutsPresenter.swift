import Foundation
import IrohaCrypto
import SoraFoundation

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!

    private let addressFactory = SS58AddressFactory()
    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private lazy var formatterFactory = AmountFormatterFactory()
    private var payoutItems: [PayoutInfo] = []
    private var priceData: PriceData?

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createCellViewModels(
        for payouts: [PayoutInfo]
    ) -> [StakingRewardHistoryCellViewModel] {
        payouts.map { payout in
            StakingRewardHistoryCellViewModel(
                addressOrName: self.addressTitle(payout.validator),
                daysLeftText: payout.era.description,
                tokenAmountText: "+" + self.tokenAmountText(payout.reward),
                usdAmountText: priceText(payout.reward, priceData: priceData)
            )
        }
    }

    private func addressTitle(_ accountId: Data) -> String {
        if let address = try? addressFactory.addressFromAccountId(data: accountId, type: chain.addressType) {
            return address
        }
        return ""
    }

    private func tokenAmountText(_ value: Decimal) -> String {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        return balanceViewModelFactory.amountFromValue(value).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?) -> String {
        guard let priceData = priceData else {
            return "$0"
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }

    private func defineBottomButtonTitle(
        for payouts: [PayoutInfo]
    ) -> String {
        let totalReward = payouts
            .reduce(into: Decimal(0)) { reward, payout in
                reward += payout.reward
            }
        let amountText = tokenAmountText(totalReward)
        return "Payout all (\(amountText))"
    }

    private func updateView() {
        if payoutItems.isEmpty {
            view?.showEmptyView()
        } else {
            let viewModel = StakingPayoutViewModel(
                cellViewModels: createCellViewModels(for: payoutItems),
                bottomButtonTitle: defineBottomButtonTitle(for: payoutItems)
            )
            view?.reload(with: viewModel)
        }
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsPresenterProtocol {
    func setup() {
        view?.hideEmptyView()
        view?.startLoading()
        interactor.setup()
    }

    func handleSelectedHistory(at index: Int) {
        guard index >= 0, index < payoutItems.count else {
            return
        }
        let payoutItem = payoutItems[index]
        wireframe.showRewardDetails(from: view, payoutItem: payoutItem, chain: chain)
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view)
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {
    func didReceive(result: Result<PayoutsInfo, Error>) {
        view?.stopLoading()

        switch result {
        case let .success(payoutInfo):
            payoutItems = payoutInfo.payouts
            updateView()
        case .failure:
            payoutItems = []
            let emptyViewModel = StakingPayoutViewModel(
                cellViewModels: [],
                bottomButtonTitle: ""
            )
            view?.reload(with: emptyViewModel)

            view?.showRetryState()
        }
    }

    func didReceive(priceResult: Result<PriceData?, Error>) {
        switch priceResult {
        case let .success(priceData):
            self.priceData = priceData

            if !payoutItems.isEmpty {
                updateView()
            }
        case .failure:
            priceData = nil
            updateView()
        }
    }
}
