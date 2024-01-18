import Foundation
import SSFModels

struct ReefStakingPageReponse {
    let result: [RewardOrSlashData]
    let isLastPage: Bool
}

final class ReefStakingRewardsFetcher {
    static let pageSize: Int = 50
    private let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    func queryString(address: String, offset: Int) -> String {
        """
        query MyQuery {
                stakingsConnection(orderBy: timestamp_DESC, where: {signer: {id_eq: "\(address)"}}, first: \(Self.pageSize), after: "\(offset)") {
                    edges {
                      node {
                        id
                        type
                        amount
                        timestamp
                        signer {
                          id
                        }
                      }
                    }
                    totalCount
                  }
        }
        """
    }

    private func loadNewRewards(
        address: String,
        rewards: [RewardOrSlashData]
    ) async throws -> ReefStakingPageReponse {
        guard let blockExplorer = chain.externalApi?.staking else {
            throw StakingRewardsFetcherError.missingBlockExplorer(chain: chain.name)
        }

        let request = try StakingRewardsRequest(
            baseURL: blockExplorer.url,
            query: queryString(address: address, offset: rewards.count + 1)
        )
        let worker = NetworkWorker()
        let response: GraphQLResponse<ReefResponseData> = try await worker.performRequest(with: request)

        switch response {
        case let .data(data):
            let updatedRewards = rewards + data.data
            let isLastPage = (data.stakingsConnection?.totalCount).or(rewards.count) <= updatedRewards.count

            return ReefStakingPageReponse(
                result: updatedRewards,
                isLastPage: isLastPage
            )
        case let .errors(error):
            throw error
        }
    }
}

extension ReefStakingRewardsFetcher: StakingRewardsFetcher {
    func fetchAllRewards(
        address: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) async throws -> [RewardOrSlashData] {
        var rewards: [RewardOrSlashData] = []
        var allRewardsFetched: Bool = false

        while !allRewardsFetched {
            let response = try await loadNewRewards(
                address: address,
                rewards: rewards
            )

            rewards.append(contentsOf: response.result)

            allRewardsFetched = response.isLastPage
        }

        return rewards
    }
}
