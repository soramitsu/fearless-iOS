import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class SubqueryRewardsSource {
    typealias Model = [SubqueryRewardItemData]

    let address: String
    let url: URL

    init(
        address: AccountAddress,
        url: URL
    ) {
        self.address = address
        self.url = url
    }
}

extension SubqueryRewardsSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let params = self.requestParams(accountAddress: self.address)
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
                .compactMap { SubqueryHistoryElementData(from: $0) }
                .compactMap(\.reward)
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func requestParams(accountAddress: AccountAddress) -> String {
        """
        {
          query {
            historyElements(
              filter: {
                not:{ reward:{equalTo:\"null\"}},
                address:{equalTo:\"\(accountAddress)\"}
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
