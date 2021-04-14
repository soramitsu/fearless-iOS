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

    func handleSelectedHistory(at _: IndexPath) {
        // TODO: get model by indexPath -> pass to wireframe
        wireframe.showRewardDetails(from: view)
    }

    func handlePayoutAction() {
        wireframe.showRewardDetails(from: view)
    }

    private func createCellViewModels(
        for payouts: [PayoutItem]
    ) -> [StakingRewardHistoryCellViewModel] {
        payouts.map { payoutByValidator -> [StakingRewardHistoryCellViewModel] in
            payoutByValidator.rewardsByEra.map { era, reward in
                StakingRewardHistoryCellViewModel(
                    addressOrName: self.addressTitle(payoutByValidator.validatorAccount),
                    daysLeftText: era.description,
                    tokenAmountText: "+" + self.tokenAmountText(reward),
                    usdAmountText: "$1.4"
                )
            }
        }
        .flatMap { $0 }
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
                let viewModel = StakingPayoutViewModel(
                    cellViewModels: createCellViewModels(for: payouts),
                    bottomButtonTitle: defineBottomButtonTitle(for: payouts)
                )
                view?.reload(with: viewModel)
            }
        case let .failure(error):
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
