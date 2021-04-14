import Foundation

typealias PayoutRewardsClosure = (Result<PayoutsInfo, Error>) -> Void

/// StakingPayoutService
protocol PayoutRewardsServiceProtocol {
    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure)
}

enum PayoutError: Error {
    case unknown
}
