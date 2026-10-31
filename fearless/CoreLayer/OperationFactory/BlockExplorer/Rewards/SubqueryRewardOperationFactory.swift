import Foundation
import RobinHood
import SSFUtils
import SSFModels

enum SubqueryRewardOperationFactoryError: Error {
    case urlMissing
}

final class SubqueryRewardOperationFactory {
    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    private func prepareDelegatorHistoryRequest(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            guard startTimestamp != nil || endTimestamp != nil else { return "" }
            var bounds = [String]()
            if let timestamp = startTimestamp {
                bounds.append("greaterThanOrEqualTo: \"\(timestamp)\"")
            }
            if let timestamp = endTimestamp {
                bounds.append("lessThanOrEqualTo: \"\(timestamp)\"")
            }
            return "timestamp: { \(bounds.joined(separator: ", ")) },"
        }()

        return """
        {
                    delegators(
                         filter: {
                             id: { equalToInsensitive:"\(address)"}
                        }
                     ) {
                        nodes {
                            id
                          delegatorHistoryElements(
                            orderBy: TIMESTAMP_DESC,
                            filter: {
                              amount: { isNull: false },
                              \(timestampFilter)
                              type: { equalTo: \(SubqueryDelegationAction.reward.rawValue) }
                            }
                          ) {
                              nodes {
                                id
                                blockNumber
                                amount
                                type
                                timestamp
                                delegatorId
                                collatorId
                                roundId
                              }
                          }
                        }
                     }
                }
        """
    }

    private func prepareHistoryRequestForAddress(
        _ address: String,
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

extension SubqueryRewardOperationFactory: RewardOperationFactoryProtocol {
    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
        guard RewardHistoryRequestValidator.isValid(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        ) else {
            return BaseOperation.createWithError(RewardHistoryRequestError.invalidParameters)
        }

        let queryString = prepareDelegatorHistoryRequest(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            var request = URLRequest(url: url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<RewardHistoryResponseProtocol> { data in
            do {
                let response = try JSONDecoder().decode(
                    GraphQLResponse<SubqueryDelegatorHistoryData>.self,
                    from: data
                )

                switch response {
                case let .errors(error):
                    throw error
                case let .data(response):
                    return response
                }
            } catch {
                throw error
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardOrSlashResponse> {
        guard RewardHistoryRequestValidator.isValid(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        ) else {
            return BaseOperation.createWithError(RewardHistoryRequestError.invalidParameters)
        }

        let queryString = prepareHistoryRequestForAddress(
            address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            var request = URLRequest(url: url)

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
                GraphQLResponse<SubqueryRewardOrSlashData>.self,
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
