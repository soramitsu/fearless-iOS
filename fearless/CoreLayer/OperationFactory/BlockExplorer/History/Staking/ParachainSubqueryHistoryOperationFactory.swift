import Foundation
import RobinHood
import FearlessUtils

enum SubqueryHistoryOperationFactoryError: Error {
    case urlMissing
    case incorrectInputData
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
                        {
                                    delegators(
                                         filter: {
                                             id: { equalToInsensitive:"\(delegatorAddress)"}
                                        }
                                     ) {
                                        nodes {
                                            id
                                          delegatorHistoryElements(
                                            orderBy: TIMESTAMP_DESC,
                                            filter: {
                                                amount: {isNull: false},
                                                collatorId: { equalToInsensitive: "\(collatorAddress)"}
                                                }) {
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
                                     }
                                }
        """
    }
}

extension ParachainSubqueryHistoryOperationFactory: ParachainHistoryOperationFactory {
    func createUnstakingHistoryOperation(
        delegatorAddress: String,
        collatorAddress: String
    ) -> BaseOperation<DelegatorHistoryResponse> {
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

        let resultFactory = AnyNetworkResultFactory<DelegatorHistoryResponse> { data in
            do {
                let response = try JSONDecoder().decode(
                    SubqueryResponse<SubqueryDelegatorHistoryData>.self,
                    from: data
                )

                switch response {
                case let .errors(error):
                    throw error
                case let .data(response):
                    return response
                }
            } catch {
                throw error
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
