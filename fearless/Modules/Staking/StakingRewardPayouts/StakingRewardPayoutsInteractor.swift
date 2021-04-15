import UIKit
import RobinHood

final class StakingRewardPayoutsInteractor {
    weak var presenter: StakingRewardPayoutsInteractorOutputProtocol!

    private let payoutService: PayoutRewardsServiceProtocol
    private let priceProvider: AnySingleValueProvider<PriceData>

    init(
        payoutService: PayoutRewardsServiceProtocol,
        priceProvider: AnySingleValueProvider<PriceData>
    ) {
        self.payoutService = payoutService
        self.priceProvider = priceProvider
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(priceResult: .success(nil))
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(priceResult: .success(item))
                    case .delete:
                        self?.presenter.didReceive(priceResult: .success(nil))
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(priceResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension StakingRewardPayoutsInteractor: StakingRewardPayoutsInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()

        payoutService.fetchPayoutRewards { [weak presenter] result in
            DispatchQueue.main.async {
                presenter?.didReceive(result: result)
            }
        }
    }
}
