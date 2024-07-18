import Foundation
import SoraFoundation
import SSFModels
import SSFNetwork

final class SubsquidStakingRewardsFetcher {
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
            let locale = LocalizationManager.shared.selectedLocale
            guard startTimestamp != nil || endTimestamp != nil else { return "" }

            var result = "AND: {"
            let dateFormatter = DateFormatter.suibsquidInputDate.value(for: locale)
            if let startTimestamp = startTimestamp {
                let startDate = Date(timeIntervalSince1970: TimeInterval(startTimestamp))
                let startDateString = dateFormatter.string(from: startDate)
                result.append("timestamp_gte:\"\(startDateString)\"")
            }

            if let endTimestamp = endTimestamp {
                let endDate = Date(timeIntervalSince1970: TimeInterval(endTimestamp))
                let endDateString = dateFormatter.string(from: endDate)
                result.append("timestamp_lte:\"\(endDateString)\"")
            }
            result.append("}")
            return result
        }()

        return """
        query MyQuery {
          historyElements(orderBy: timestamp_DESC, where: {address_eq: "\(address)", \(timestampFilter), reward_isNull: false}) {
            timestamp
                id
                address
                success
                reward {
                  amount
                  era
                  stash
                  validator
                }
          }
        }
        """
    }
}

extension SubsquidStakingRewardsFetcher: StakingRewardsFetcher {
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
        let response: GraphQLResponse<ArrowsquidHistoryResponse> = try await worker.performRequest(with: request)

        switch response {
        case let .data(data):
            return data.data
        case let .errors(error):
            throw error
        }
    }
}
