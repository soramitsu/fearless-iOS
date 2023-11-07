import RobinHood
import Foundation
import SSFUtils
import IrohaCrypto
import SSFModels

final class SoraSubsquidPayoutValidatorsForNominatorFactory {
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
        BlockNetworkRequestFactory { [weak self] in
            guard let strongSelf = self else {
                throw ConvenienceError(error: "factory unavailable")
            }

            var request = URLRequest(url: strongSelf.url)

            let eraRange = historyRange()
            let params = strongSelf.requestParams(accountAddress: address, eraRange: eraRange)
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
                let nodes = resultData.data?.stakingEraNominators?.arrayValue
            else { return [] }
            let addresses = nodes.compactMap { $0.nominations }.compactMap { $0.arrayValue?.first?.validator?.validator?.id }

            return try addresses.compactMap {
                guard let address = $0.stringValue else {
                    return nil
                }

                return try AddressFactory.accountId(from: address, chain: chainAsset.chain)
            }
        }
    }

    private func requestParams(accountAddress: AccountAddress, eraRange: EraRange?) -> String {
        let eraFilter: String = eraRange.map {
            "AND: {era: {index_gte: \($0.start), index_lte: \($0.end)}},"
        } ?? ""

        return """
        query MyQuery {
          stakingEraNominators(where:{ \(eraFilter) staker: {id_containsInsensitive: "\(accountAddress)"}}) {
             nominations {
               validator {
                 validator {
                   id
                 }
               }
             }
           }
        }
        """
    }
}

extension SoraSubsquidPayoutValidatorsForNominatorFactory: PayoutValidatorsFactoryProtocol {
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
