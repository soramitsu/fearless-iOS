import UIKit

final class StakingRewardPayoutsInteractor {
    weak var presenter: StakingRewardPayoutsInteractorOutputProtocol!
}

extension StakingRewardPayoutsInteractor: StakingRewardPayoutsInteractorInputProtocol {}