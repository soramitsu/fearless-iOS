import Foundation
import SSFModels
import SSFNetwork

final class SubqueryStakingRewardsFetcher {
    private let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    func queryString(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            guard startTimestamp != nil || endTimestamp != nil else { return "" }
            var result = "timestamp:{"
            if let timestamp = startTimestamp {
                result.append("greaterThanOrEqualTo:\"\(timestamp)\",")
            }
            if let timestamp = endTimestamp {
                result.append("lessThanOrEqualTo:\"\(timestamp)\",")
            }
            result.append("}")
            return result
        }()

        return """
        {
                                historyElements(
                                     orderBy: TIMESTAMP_DESC,
                                     filter: {
                                         address: { equalTo: \"\(address)\"},
                                         reward: { isNull: false },
                                        \(timestampFilter)
                                     }
                                 ) {
                                    nodes {
                                        id
                                        timestamp
                                        address
                                        reward
                }
             }
        }

        """
    }
}

extension SubqueryStakingRewardsFetcher: StakingRewardsFetcher {
    func fetchAllRewards(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) async throws -> [RewardOrSlashData] {
        guard let blockExplorer = chain.externalApi?.staking else {
            throw StakingRewardsFetcherError.missingBlockExplorer(chain: chain.name)
        }

        let queryString = queryString(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let request = try StakingRewardsRequest(
            baseURL: blockExplorer.url,
            query: queryString
        )
        let worker = NetworkWorkerImpl()
        let response: GraphQLResponse<SubqueryRewardOrSlashData> = try await worker.performRequest(with: request)

        switch response {
        case let .data(data):
            return data.data
        case let .errors(error):
            throw error
        }
    }
}
