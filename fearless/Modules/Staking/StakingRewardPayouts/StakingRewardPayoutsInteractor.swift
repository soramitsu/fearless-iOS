import UIKit

final class StakingRewardPayoutsInteractor {
    weak var presenter: StakingRewardPayoutsInteractorOutputProtocol!

    private let payoutService: PayoutRewardsServiceProtocol

    init(payoutService: PayoutRewardsServiceProtocol) {
        self.payoutService = payoutService
    }
}

extension StakingRewardPayoutsInteractor: StakingRewardPayoutsInteractorInputProtocol {
    func setup() {
        payoutService.fetchPayoutRewards { [weak presenter] result in
            DispatchQueue.main.async {
                presenter?.didReceive(result: result)
            }
        }
    }
}
