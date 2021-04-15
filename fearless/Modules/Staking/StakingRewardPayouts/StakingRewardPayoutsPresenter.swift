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
    private var payoutItems: [StakingPayoutItem] = []

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
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

    private func createPayoutItems(from payouts: [PayoutItem]) -> [StakingPayoutItem] {
        payouts.map { payoutByValidator -> [StakingPayoutItem] in
            payoutByValidator.rewardsByEra.map { era, reward in
                StakingPayoutItem(
                    validator: payoutByValidator.validatorAccount,
                    era: era,
                    reward: reward
                )
            }
        }
        .flatMap { $0 }
    }

    private func createCellViewModels(
        for payouts: [StakingPayoutItem]
    ) -> [StakingRewardHistoryCellViewModel] {
        payouts.map { payout in
            StakingRewardHistoryCellViewModel(
                addressOrName: self.addressTitle(payout.validator),
                daysLeftText: payout.era.description,
                tokenAmountText: "+" + self.tokenAmountText(payout.reward),
                usdAmountText: "$0"
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
        balanceViewModelFactory.amountFromValue(value).value(for: .autoupdatingCurrent)
    }

    private func defineBottomButtonTitle(
        for payouts: [PayoutItem]
    ) -> String {
        let totalReward = payouts
            .reduce(into: Decimal(0)) { reward, payout in
                reward += payout.totalReward
            }
        let amountText = tokenAmountText(totalReward)
        return "Payout all (\(amountText))"
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {
    func didReceive(result: Result<[PayoutItem], Error>) {
        view?.stopLoading()

        switch result {
        case let .success(payouts):
            if payouts.isEmpty {
                view?.showEmptyView()
            } else {
                let payoutItems = createPayoutItems(from: payouts)
                self.payoutItems = payoutItems
                let viewModel = StakingPayoutViewModel(
                    cellViewModels: createCellViewModels(for: payoutItems),
                    bottomButtonTitle: defineBottomButtonTitle(for: payouts)
                )
                view?.reload(with: viewModel)
            }
        case let .failure(error):
            payoutItems = []
            let emptyViewModel = StakingPayoutViewModel(
                cellViewModels: [],
                bottomButtonTitle: ""
            )
            view?.reload(with: emptyViewModel)

            view?.showRetryState()
        }
    }
}

extension PayoutItem {
    var totalReward: Decimal {
        rewardsByEra
            .reduce(into: Decimal(0)) { totalReward, tuple in
                totalReward += tuple.1
            }
    }
}
