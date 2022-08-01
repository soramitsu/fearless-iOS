import Foundation
import RobinHood
import FearlessUtils

enum SubqueryHistoryOperationFactoryError: Error {
    case urlMissing
}

protocol ParachainSubqueryHistoryOperationFactoryProtocol {
    func createUnstakingHistoryOperation(
        delegatorAddress: String,
        collatorAddress: String
    ) -> BaseOperation<SubqueryDelegatorHistoryElement>
}

final class ParachainSubqueryHistoryOperationFactory {
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    private func prepareUnstakingHistoryRequest(
        delegatorAddress: String,
        collatorAddress: String
    ) -> String {
        """
        query {
                delegatorHistoryElements(
                last: 20,
                filter: {
                    delegatorId: { equalToInsensitive: "\(delegatorAddress)"},
                    collatorId: { equalToInsensitive: "\(collatorAddress)"},
                    type: { equalTo: 1 }
        }
                ) {
                    nodes {
                      id
                      blockNumber
                      delegatorId
                      collatorId
                      timestamp
                      type
                      roundId
                      amount
                    }
                }
            }
        """
    }
}

extension ParachainSubqueryHistoryOperationFactory: ParachainSubqueryHistoryOperationFactoryProtocol {
    func createUnstakingHistoryOperation(
        delegatorAddress: String,
        collatorAddress: String
    ) -> BaseOperation<SubqueryDelegatorHistoryElement> {
        let queryString = prepareUnstakingHistoryRequest(
            delegatorAddress: delegatorAddress,
            collatorAddress: collatorAddress
        )

        let url = self.url

        let requestFactory = BlockNetworkRequestFactory {
            guard let url = url else {
                throw SubqueryHistoryOperationFactoryError.urlMissing
            }

            var request = URLRequest(url: url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryDelegatorHistoryElement> { data in
            let response = try JSONDecoder().decode(SubqueryResponse<SubqueryDelegatorHistoryElement>.self, from: data)

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
