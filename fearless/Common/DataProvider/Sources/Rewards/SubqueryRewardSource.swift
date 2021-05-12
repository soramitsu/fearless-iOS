import Foundation
import RobinHood
import FearlessUtils
import BigInt
import CommonWallet

final class SubqueryRewardSource {
    typealias Model = TotalRewardItem

    let address: String
    let url: URL
    let chain: Chain

    init(
        address: String,
        url: URL,
        chain: Chain
    ) {
        self.address = address
        self.url = url
        self.chain = chain
    }
}

extension SubqueryRewardSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<TotalRewardItem?> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let params = "{sumReward(id: \"\(self.address)\"){accountTotal}}"
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<TotalRewardItem?> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)

            return resultData.data?.sumReward?.accountTotal?.stringValue
                .map { BigUInt($0) }?
                .map { Decimal.fromSubstrateAmount($0, precision: self.chain.addressType.precision) }?
                .map {
                    TotalRewardItem(
                        address: self.address,
                        blockNumber: nil,
                        extrinsicIndex: nil,
                        amount: AmountDecimal(value: $0
                        )
                    )
                }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
