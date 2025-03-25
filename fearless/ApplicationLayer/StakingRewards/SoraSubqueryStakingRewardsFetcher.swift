import Foundation
import SSFModels
import SSFNetwork
import RobinHood

final class SoraSubqueryStakingRewardsFetcher {
    private let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    func queryString(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        var filter = """
                    {
                        and: [],
                        method: {equalTo: "Rewarded"},
                        address: {equalTo: "\(address)"},
                        module: {equalTo: "staking"}
                }
        """

        if let timestamp = startTimestamp {
            let startTimestampValue = "\(timestamp)"
            filter.append(", dataFrom: {greaterThanOrEqualTo: \(startTimestampValue)}")
        }
        if let timestamp = endTimestamp {
            let endTimestampValue = "\(timestamp)"
            filter.append(", dataTo: {lessThanOrEqualTo: \(endTimestampValue)}")
        }

        return """
        {
          historyElements(
            after: null
            orderBy: TIMESTAMP_DESC
            filter: \(filter)
          ) {
            pageInfo {
              startCursor
              endCursor
            }
            nodes {
              id
              timestamp
              address
              data
              method
              module
              blockHash
              blockHeight
            }
          }
        }
        """
    }
}

extension SoraSubqueryStakingRewardsFetcher: StakingRewardsFetcher {
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
        let response: GraphQLResponse<SoraSubqueryRewardOrSlashData> = try await worker.performRequest(with: request)

        switch response {
        case let .data(data):
            return data.data
        case let .errors(error):
            throw error
        }
    }
}

extension SoraSubqueryStakingRewardsFetcher: RewardOperationFactoryProtocol {
    func createLastRoundOperation() -> BaseOperation<String> {
        BaseOperation.createWithError(SoraRewardOperationFactoryError.stakingTypeUnsupported)
    }

    func createAprOperation(
        for _: @escaping () throws -> [AccountId],
        dependingOn _: BaseOperation<String>
    ) -> BaseOperation<CollatorAprResponse> {
        BaseOperation.createWithError(SoraRewardOperationFactoryError.stakingTypeUnsupported)
    }

    func createDelegatorRewardsOperation(
        address _: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
        BaseOperation.createWithError(SoraRewardOperationFactoryError.stakingTypeUnsupported)
    }

    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardOrSlashResponse> {
        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let strongSelf = self else {
                throw CommonError.internal
            }
            guard let blockExplorer = strongSelf.chain.externalApi?.staking else {
                throw StakingRewardsFetcherError.missingBlockExplorer(chain: strongSelf.chain.name)
            }

            let queryString = strongSelf.queryString(
                address: address,
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp
            )

            var request = URLRequest(url: blockExplorer.url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<RewardOrSlashResponse> { data in
            let response = try JSONDecoder().decode(
                GraphQLResponse<SoraSubqueryRewardOrSlashData>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
