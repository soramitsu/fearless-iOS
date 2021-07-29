import Foundation
import RobinHood
import FearlessUtils
import BigInt

struct SubqueryTransferData: Decodable {
    let transferId: String
    let toId: String
    let fromId: String
    let amount: Decimal?
    let createdAt: String

    init?(from json: JSON, chain: Chain) {
        guard
            let transferId = json.id?.stringValue,
            let fromId = json.fromId?.stringValue,
            let toId = json.toId?.stringValue,
            let createdAt = json.createdAt?.stringValue
        else { return nil }

        let amount = json.amount?.stringValue
            .map { BigUInt($0) }?
            .map { Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision) }
            ?? Decimal(0)

        self.transferId = transferId
        self.toId = toId
        self.fromId = fromId
        self.createdAt = createdAt
        self.amount = amount
    }
}

final class SubqueryTransfersSource {
    typealias Model = [SubqueryTransferData]

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

extension SubqueryTransfersSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryTransferData]?> {
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

        let resultFactory = AnyNetworkResultFactory<[SubqueryTransferData]?> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)

            let nodes = resultData.data?.query?.transfers?.nodes
            return nodes?.arrayValue?
                .compactMap { SubqueryTransferData(from: $0, chain: self.chain) }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func requestParams(accountAddress: AccountAddress) -> String {
        """
        {
            query {
                transfers(
                    last:100000000
                    filter: {or: [{toId: {equalTo: \"\(accountAddress)\"}}, {fromId: {equalTo: \"\(accountAddress)\"}}]}
                ) {
                    nodes {
                        id
                        amount
                        fromId
                        toId
                        createdAt
                    }
                }
            }
        }
        """
    }
}
