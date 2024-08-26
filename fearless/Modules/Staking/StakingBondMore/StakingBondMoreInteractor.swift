import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore
import SSFUtils
import SSFModels

final class StakingBondMoreInteractor: AccountFetching {
    weak var presenter: StakingBondMoreInteractorOutputProtocol?

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingBondMoreStrategy

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingBondMoreStrategy
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }

    func estimateFee(reuseIdentifier: String?, builderClosure: ExtrinsicBuilderClosure?) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }
}
