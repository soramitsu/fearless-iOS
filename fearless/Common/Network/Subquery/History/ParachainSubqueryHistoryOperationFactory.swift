import Foundation
import RobinHood
import FearlessUtils

enum SubqueryHistoryOperationFactoryError: Error {
    case urlMissing
    case incorrectInputData
}

protocol ParachainSubqueryHistoryOperationFactoryProtocol {
    func createUnstakingHistoryOperation(
        delegatorAddress: String,
        collatorAddress: String
    ) -> BaseOperation<SubqueryDelegatorHistoryData>
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

extension ParachainSubqueryHistoryOperationFactory: ParachainSubqueryHistoryOperationFactoryProtocol {
    func createUnstakingHistoryOperation(
        delegatorAddress: String,
        collatorAddress: String
    ) -> BaseOperation<SubqueryDelegatorHistoryData> {
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

        let resultFactory = AnyNetworkResultFactory<SubqueryDelegatorHistoryData> { data in
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SubqueryHistoryOperationFactoryError.incorrectInputData
            }

            guard let dataDict = json["data"] as? [String: Any] else {
                throw SubqueryHistoryOperationFactoryError.incorrectInputData
            }

            let historyData = try SubqueryDelegatorHistoryData(json: dataDict)

            return historyData
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
