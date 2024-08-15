import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class StakingBalanceInteractor: AccountFetching {
    weak var presenter: StakingBalanceInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let strategy: StakingBalanceStrategy

    init(
        chainAsset: ChainAsset,
        strategy: StakingBalanceStrategy
    ) {
        self.chainAsset = chainAsset
        self.strategy = strategy
    }
}

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }

    func refresh() {
        strategy.setup()
    }
}
