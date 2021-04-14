import Foundation

typealias PayoutRewardsClosure = (Result<[Data: [(EraIndex, Decimal)]], Error>) -> Void

/// StakingPayoutService
protocol PayoutRewardsServiceProtocol {
    func update(to chain: Chain)
    // fetchPayouts
    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure)
}

enum PayoutError: Error {
    case unknown
}
