import Foundation
import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import SSFModels
import IrohaCrypto

final class StakingUnbondConfirmInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondConfirmInteractorOutputProtocol!

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingUnbondConfirmStrategy

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingUnbondConfirmStrategy
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingUnbondConfirmInteractor: StakingUnbondConfirmInteractorInputProtocol {
    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        strategy.estimateFee(
            builderClosure: builderClosure,
            reuseIdentifier: reuseIdentifier
        )
    }

    func setup() {
        strategy.setup()
    }
}
