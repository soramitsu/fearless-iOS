import UIKit
import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import IrohaCrypto
import SSFModels

final class StakingRedeemConfirmationInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRedeemConfirmationInteractorOutputProtocol!

    let strategy: StakingRedeemConfirmationStrategy

    init(
        strategy: StakingRedeemConfirmationStrategy
    ) {
        self.strategy = strategy
    }
}

extension StakingRedeemConfirmationInteractor: StakingRedeemConfirmationInteractorInputProtocol {
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }

    func setup() {
        strategy.setup()
    }
}
