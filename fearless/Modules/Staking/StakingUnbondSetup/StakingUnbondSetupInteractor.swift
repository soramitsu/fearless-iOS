import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import IrohaCrypto
import SSFModels

final class StakingUnbondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!

    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let strategy: StakingUnbondSetupStrategy

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingUnbondSetupStrategy
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }
}
