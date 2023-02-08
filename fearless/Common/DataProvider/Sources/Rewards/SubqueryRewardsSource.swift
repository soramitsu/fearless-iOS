import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class ParachainSubqueryRewardsSource {
    typealias Model = [SubqueryRewardItemData]

    private let address: AccountAddress
    private let url: URL
    private let startTimestamp: Int64?
    private let endTimestamp: Int64?
    private let operationFactory: RewardOperationFactoryProtocol

    init(
        address: AccountAddress,
        url: URL,
        startTimestamp: Int64? = nil,
        endTimestamp: Int64? = nil,
        operationFactory: RewardOperationFactoryProtocol
    ) {
        self.address = address
        self.url = url
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.operationFactory = operationFactory
    }
}

extension ParachainSubqueryRewardsSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let rewardOperation = operationFactory.createDelegatorRewardsOperation(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let address = self.address

        let mappingOperation = ClosureOperation<[SubqueryRewardItemData]?> {
            let rewards = try rewardOperation.extractNoCancellableResultData()
            return rewards.rewardHistory(for: address).compactMap { wrappedReward in
                guard
                    let timestamp = Int64(wrappedReward.timestampInSeconds)
                else {
                    return nil
                }
                return SubqueryRewardItemData(
                    eventId: wrappedReward.id,
                    timestamp: timestamp,
                    validatorAddress: "",
                    era: EraIndex(0),
                    stashAddress: address,
                    amount: wrappedReward.amount,
                    isReward: wrappedReward.type == .reward
                )
            }
        }

        mappingOperation.addDependency(rewardOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [rewardOperation])
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
                                  delegatorHistoryElements(orderBy: TIMESTAMP_DESC,filter: { amount: {isNull: false}, \(timestampFilter), type: { equalTo: 0 }}) {
                                      nodes {
                                        id
                                        blockNumber
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

    private let address: AccountAddress
    private let url: URL
    private let startTimestamp: Int64?
    private let endTimestamp: Int64?

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
        let url = self.url
        let params = requestParams()

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

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
