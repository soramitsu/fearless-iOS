import Foundation

typealias PayoutRewardsClosure = (Result<PayoutsInfo, Error>) -> Void

/// StakingPayoutService
protocol PayoutRewardsServiceProtocol {
    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure)
}

enum PayoutError: LocalizedError {
    case unknown

    var errorDescription: String? {
        "No data retrieved." // TODO: localize
    }
}
