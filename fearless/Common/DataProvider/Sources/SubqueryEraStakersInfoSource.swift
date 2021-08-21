import RobinHood
import Foundation
import FearlessUtils

final class SubqueryEraStakersInfoSource {
    let url: URL
    let address: AccountAddress

    init(url: URL, address: AccountAddress) {
        self.url = url
        self.address = address
    }

    func fetch(
        historyRange: @escaping () -> ChainHistoryRange?
    ) -> CompoundOperationWrapper<[SubqueryEraValidatorInfo]> {
        let requestFactory = createRequestFactory(historyRange: historyRange)
        let resultFactory = createResultFactory()

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func createRequestFactory(
        historyRange: @escaping () -> ChainHistoryRange?
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let erasRange = historyRange()?.erasRange
            let params = self.requestParams(accountAddress: self.address, erasRange: erasRange)
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }
    }

    private func createResultFactory() -> AnyNetworkResultFactory<[SubqueryEraValidatorInfo]> {
        AnyNetworkResultFactory<[SubqueryEraValidatorInfo]> { data in
            guard
                let resultData = try? JSONDecoder().decode(JSON.self, from: data),
                let nodes = resultData.data?.query?.eraValidatorInfos?.nodes?.arrayValue
            else { return [] }

            return nodes.compactMap { SubqueryEraValidatorInfo(from: $0) }
        }
    }

    private func requestParams(accountAddress: AccountAddress, erasRange: [EraIndex]?) -> String {
        let eraFilter: String = {
            guard let fistRange = erasRange?.first, let lastRange = erasRange?.last else { return "" }
            return "era:{greaterThanOrEqualTo: \(fistRange), lessThanOrEqualTo: \(lastRange)},"
        }()

        return """
        {
          query {
            eraValidatorInfos(
              filter:{
                \(eraFilter)
                others:{contains:[{who:\"\(accountAddress)\"}]}
              }
            ) {
              nodes {
                id
                address
                era
                total
                own
                others
              }
            }
          }
        }
        """
    }
}
