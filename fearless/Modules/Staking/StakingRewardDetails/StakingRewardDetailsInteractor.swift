import UIKit

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!

    private let payoutItem: StakingPayoutItem

    init(payoutItem: StakingPayoutItem) {
        self.payoutItem = payoutItem
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {
    func setup() {
        // TODO: convert reward to usd
        DispatchQueue.main.async {
            self.presenter.didRecieve(payoutItem: self.payoutItem)
        }
    }
}
