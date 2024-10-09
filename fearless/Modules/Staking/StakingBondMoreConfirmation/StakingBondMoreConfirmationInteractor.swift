import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore
import SSFUtils
import SSFModels

final class StakingBondMoreConfirmationInteractor: AccountFetching {
    weak var presenter: StakingBondMoreConfirmationOutputProtocol!

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingBondMoreConfirmationStrategy

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingBondMoreConfirmationStrategy
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingBondMoreConfirmationInteractor: StakingBondMoreConfirmationInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }
}
