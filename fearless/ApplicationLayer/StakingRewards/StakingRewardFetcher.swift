import Foundation

enum StakingRewardsFetcherError: Error {
    case missingBlockExplorer(chain: String)
}

protocol StakingRewardsFetcher {
    func fetchAllRewards(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) async throws -> [RewardOrSlashData]
}
