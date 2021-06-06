import Foundation
import RobinHood
import FearlessUtils
import BigInt
import CommonWallet
import XCTest
@testable import fearless

struct Transfer: Decodable {
    let toId: String
    let fromId: String
    let amount: Decimal?
    let id: String
    let createdAd: String
}

final class SubqueryTransferSource {
    typealias Model = [Transfer]

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

extension SubqueryTransferSource: SingleValueProviderSourceProtocol {

    func fetchOperation() -> CompoundOperationWrapper<[Transfer]?> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let params = """
            {
                query {
                    transfers(
                          last:100000000
                          filter: {or: [{toId: {equalTo: \"\(self.address)\"}}, {fromId: {equalTo: \"\(self.address)\"}}]}
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
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[Transfer]?> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)

            let nodes = resultData.data?.query?.transfers?.nodes
            return nodes?.arrayValue?
                .compactMap { node -> Transfer? in
                    guard
                        let id = node.id?.stringValue,
                        let fromId = node.fromId?.stringValue,
                        let toId = node.toId?.stringValue,
                        let createdAt = node.createdAt?.stringValue
                    else { return nil }

                    let amount = node.amount?.stringValue
                        .map { BigUInt($0) }?
                        .map { Decimal.fromSubstrateAmount($0, precision: self.chain.addressType.precision) }
                        ?? Decimal(0)
                    return Transfer(
                        toId: toId,
                        fromId: fromId,
                        amount: amount,
                        id: id,
                        createdAd: createdAt
                    )
                }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

class SubqueryTransferSourceTests: XCTestCase {

    func testConnection() {
        let source = SubqueryTransferSource(
            address: "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu",
            url: URL(string: "http://localhost:3000/")!,
            chain: .polkadot
        )
        let operation = source.fetchOperation()
        OperationQueue().addOperations(operation.allOperations, waitUntilFinished: true)
        do {
            let transfers = try operation.targetOperation.extractNoCancellableResultData() ?? []
            XCTAssert(!transfers.isEmpty)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
