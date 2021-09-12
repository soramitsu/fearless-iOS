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
        eraRangeClosure: @escaping () -> EraRange?
    ) -> CompoundOperationWrapper<[SubqueryEraValidatorInfo]> {
        let requestFactory = createRequestFactory(eraRangeClosure: eraRangeClosure)
        let resultFactory = createResultFactory()

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func createRequestFactory(
        eraRangeClosure: @escaping () -> EraRange?
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let eraRange = eraRangeClosure()
            let params = self.requestParams(accountAddress: self.address, eraRange: eraRange)
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

    private func requestParams(accountAddress: AccountAddress, eraRange: EraRange?) -> String {
        let eraFilter: String = {
            guard let fistRange = eraRange?.start, let lastRange = eraRange?.end else { return "" }
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
              }
            }
          }
        }
        """
    }
}
