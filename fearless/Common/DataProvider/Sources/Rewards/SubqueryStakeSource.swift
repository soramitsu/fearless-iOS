import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class SubqueryStakeSource {
    typealias Model = [SubqueryStakeChangeData]

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

extension SubqueryStakeSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryStakeChangeData]?> {
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

        let resultFactory = AnyNetworkResultFactory<[SubqueryStakeChangeData]?> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)

            let nodes = resultData.data?.query?.stakeChanges?.nodes
            return nodes?.arrayValue?
                .compactMap { SubqueryStakeChangeData(from: $0) }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func requestParams(accountAddress: AccountAddress) -> String {
        """
        {
          query {
            stakeChanges(
              filter: {
                address:{equalTo:\"\(accountAddress)\"}
              }
            ) {
              nodes {
                id
                address
                timestamp
                amount
                type
              }
            }
          }
        }
        """
    }
}
