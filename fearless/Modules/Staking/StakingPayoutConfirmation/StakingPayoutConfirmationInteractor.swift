import Foundation
import SoraKeystore

import RobinHood
import IrohaCrypto
import BigInt
import SSFModels

final class StakingPayoutConfirmationInteractor: AccountFetching {

    private let strategy: StakingPayoutConfirmationStrategy

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol?

    init(
        strategy: StakingPayoutConfirmationStrategy
    ) {
        self.strategy = strategy
    }
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.estimateFee(builderClosure: builderClosure)
    }

    func submitPayout(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submitPayout(builderClosure: builderClosure)
    }
}
