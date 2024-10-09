import UIKit
import RobinHood
import SSFModels

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!
    private let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {}
