import Foundation

typealias PayoutRewardsClosure = (Result<[PayoutItem], Error>) -> Void

struct PayoutItem {
    let validatorAccount: Data
    let rewardsByEra: [(EraIndex, Decimal)]
}

/// StakingPayoutService
protocol PayoutRewardsServiceProtocol {
    func update(to chain: Chain)
    // fetchPayouts
    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure)
}

enum PayoutError: Error {
    case unknown
}
