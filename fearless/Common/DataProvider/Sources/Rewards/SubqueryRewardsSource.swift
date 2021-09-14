import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class SubqueryRewardsSource {
    typealias Model = [SubqueryRewardItemData]

    let address: String
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

extension SubqueryRewardsSource: SingleValueProviderSourceProtocol {
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
