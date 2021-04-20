import Foundation

typealias PayoutRewardsClosure = (Result<PayoutsInfo, PayoutRewardsServiceError>) -> Void

/// StakingPayoutService
protocol PayoutRewardsServiceProtocol {
    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure)
}

enum PayoutRewardsServiceError: Error {
    case unknown
}
