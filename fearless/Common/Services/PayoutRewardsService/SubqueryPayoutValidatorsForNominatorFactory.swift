import RobinHood
import Foundation
import SSFUtils
import IrohaCrypto
import SSFModels

final class SubqueryPayoutValidatorsForNominatorFactory {
    private let url: URL
    private let chainAsset: ChainAsset

    init(url: URL, chainAsset: ChainAsset) {
        self.url = url
        self.chainAsset = chainAsset
    }

    private func createRequestFactory(
        address: AccountAddress,
        historyRange: @escaping () -> EraRange?
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let eraRange = historyRange()
            let params = self.requestParams(accountAddress: address, eraRange: eraRange)
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

    private func createResultFactory() -> AnyNetworkResultFactory<[AccountId]> {
        AnyNetworkResultFactory<[AccountId]> { [chainAsset] data in
            guard
                let resultData = try? JSONDecoder().decode(JSON.self, from: data),
                let nodes = resultData.data?.query?.eraValidatorInfos?.nodes?.arrayValue
            else { return [] }

            return try nodes.compactMap { node in
                guard let address = node.address?.stringValue else {
                    return nil
                }

                return try AddressFactory.accountId(from: address, chain: chainAsset.chain)
            }
        }
    }

    private func requestParams(accountAddress: AccountAddress, eraRange: EraRange?) -> String {
        let eraFilter: String = eraRange.map {
            "era:{greaterThanOrEqualTo: \($0.start), lessThanOrEqualTo: \($0.end)},"
        } ?? ""

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
                address
              }
            }
          }
        }
        """
    }
}

extension SubqueryPayoutValidatorsForNominatorFactory: PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure _: @escaping () throws -> EraRange?
    ) -> CompoundOperationWrapper<[AccountId]> {
        let requestFactory = createRequestFactory(address: address, historyRange: { nil })
        let resultFactory = createResultFactory()

        let networkOperation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: networkOperation)
    }
}
