import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class ParachainSubqueryRewardsSource {
    typealias Model = [SubqueryRewardItemData]

    let address: AccountAddress
    let url: URL
    let startTimestamp: Int64?
    let endTimestamp: Int64?

    init(
        address: AccountAddress,
        url: URL,
        startTimestamp: Int64? = nil,
        endTimestamp: Int64? = nil
    ) {
        self.address = address
        self.url = url
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
    }
}

extension ParachainSubqueryRewardsSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let params = self.requestParams()
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[SubqueryRewardItemData]?> { data in
            let response = try JSONDecoder().decode(SubqueryResponse<SubqueryDelegatorHistoryData>.self, from: data)

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response.delegators.nodes.first(where: { historyElement in
                    historyElement.id.lowercased() == self.address.lowercased()
                })?.delegatorHistoryElements.nodes.compactMap { wrappedReward in
                    guard
                        let timestamp = Int64(wrappedReward.timestamp)
                    else {
                        return nil
                    }
                    return SubqueryRewardItemData(
                        eventId: wrappedReward.id,
                        timestamp: timestamp,
                        validatorAddress: "",
                        era: EraIndex(0),
                        stashAddress: self.address,
                        amount: wrappedReward.amount,
                        isReward: wrappedReward.type == 0
                    )
                }
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func requestParams() -> String {
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
                            delegators(
                                 filter: {
                                     id: { equalToInsensitive:"\(address)"}
                                }
                             ) {
                                nodes {
                                    id
                                  delegatorHistoryElements(filter: { amount: {isNull: false}}) {
                                      nodes {
                                        id
                                        amount
                                        type
                                        timestamp
                                        delegator {
                                            id
                                        }
                                      }
                                  }
                                }
                             }
                        }
        """
    }
}

final class RelaychainSubqueryRewardsSource {
    typealias Model = [SubqueryRewardItemData]

    let address: AccountAddress
    let url: URL
    let startTimestamp: Int64?
    let endTimestamp: Int64?

    init(
        address: AccountAddress,
        url: URL,
        startTimestamp: Int64? = nil,
        endTimestamp: Int64? = nil
    ) {
        self.address = address
        self.url = url
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
    }
}

extension RelaychainSubqueryRewardsSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let params = self.requestParams()
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[SubqueryRewardItemData]?> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)

            let nodes = resultData.data?.query?.historyElements?.nodes
            return nodes?.arrayValue?
                .compactMap { SubqueryRewardItemData(from: $0) }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func requestParams() -> String {
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
          query {
            historyElements(
              orderBy: TIMESTAMP_ASC,
              filter: {
                not:{ reward:{equalTo:\"null\"}},
                address:{equalTo:\"\(address)\"},
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
        }
        """
    }
}
