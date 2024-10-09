import RobinHood
import BigInt
import SSFModels

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let strategy: AnalyticsRewardsStrategy
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel

    init(
        strategy: AnalyticsRewardsStrategy,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.strategy = strategy
        self.chainAsset = chainAsset
        self.wallet = wallet
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func fetchRewards(address: AccountAddress) {
        strategy.fetchRewards(address: address)
    }

    func setup() {
        strategy.setup()
    }
}
