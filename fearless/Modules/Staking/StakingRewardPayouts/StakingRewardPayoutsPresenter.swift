import Foundation

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!
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
                    addressOrName: payoutByValidator.validatorAccount.description,
                    daysLeftText: era.description,
                    ksmAmountText: "\(reward.description) KSM",
                    usdAmountText: "$\((reward / 10.0).description)"
                )
            }
        }
        .flatMap { $0 }
    }

    private func defineBottomButtonTitle(
        for payouts: [PayoutItem]
    ) -> String {
        let totalReward = payouts
            .reduce(into: Decimal(0)) { reward, payout in
                reward += payout.totalReward
            }
        return totalReward.description
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {
    func didReceive(result: Result<[PayoutItem], Error>) {
        DispatchQueue.main.async {
            self.view?.stopLoading()

            switch result {
            case let .success(payouts):
                if payouts.isEmpty {
                    self.view?.showEmptyView()
                } else {
                    let viewModel = StakingRewardReloadViewModel(
                        cellViewModels: self.createCellViewModels(for: payouts),
                        bottomButtonTitle: self.defineBottomButtonTitle(for: payouts)
                    )
                    self.view?.reload(with: viewModel)
                }
            case let .failure(error):
                self.view?.showRetryState()
            }
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
