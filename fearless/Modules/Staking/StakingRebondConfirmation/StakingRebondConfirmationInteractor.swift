import UIKit
import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import IrohaCrypto
import SSFModels

final class StakingRebondConfirmationInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondConfirmationInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let strategy: StakingRebondConfirmationStrategy

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingRebondConfirmationStrategy
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingRebondConfirmationInteractor: StakingRebondConfirmationInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }

    func estimateFee(
        builderClosure: ExtrinsicBuilderClosure?,
        reuseIdentifier: String?
    ) {
        strategy.estimateFee(
            builderClosure: builderClosure,
            reuseIdentifier: reuseIdentifier
        )
    }
}
