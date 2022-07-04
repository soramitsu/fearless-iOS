import Foundation
import RobinHood
import FearlessUtils

protocol SubqueryRewardOperationFactoryProtocol {
    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryRewardOrSlashData>

    func createAprOperation(for idsClosure: @escaping () throws -> [AccountId]) -> BaseOperation<SubqueryCollatorDataResponse>
}

extension SubqueryRewardOperationFactoryProtocol {
    func createHistoryOperation(address: String) -> BaseOperation<SubqueryRewardOrSlashData> {
        createHistoryOperation(address: address, startTimestamp: nil, endTimestamp: nil)
    }
}

final class SubqueryRewardOperationFactory {
    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    private func prepareCollatorsAprQuery(collatorIds: [String]) -> String {
        """
        {
          collatorRounds(filter:
            {collatorId: {
              inInsensitive: \(collatorIds)
            },
            apr: { isNull: false, greaterThan: 0 }
            }
          ) {
            nodes {
              collatorId
              apr
            }
          }
        }
        """
    }

    private func prepareQueryForAddress(
        _ address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            guard startTimestamp != nil || endTimestamp != nil else { return "" }
            var result = "timestamp:{"
            if let timestamp = startTimestamp {
                result.append("greaterThanOrEqualTo:\"\(timestamp)\",")
            }
            if let timestamp = endTimestamp {
                result.append("lessThanOrEqualTo:\"\(timestamp)\",")
            }
            result.append("}")
            return result
        }()

        return """
        {
            historyElements(
                 orderBy: TIMESTAMP_DESC,
                 filter: {
                     address: { equalTo: \"\(address)\"},
                     reward: { isNull: false },
                    \(timestampFilter)
                 }
             ) {
                nodes {
                    id
                    timestamp
                    address
                    reward
                }
             }
        }
        """
    }
}

extension SubqueryRewardOperationFactory: SubqueryRewardOperationFactoryProtocol {
    func createAprOperation(for idsClosure: @escaping () throws -> [AccountId]) -> BaseOperation<SubqueryCollatorDataResponse> {
        guard let url = url else {
            return ClosureOperation { SubqueryCollatorDataResponse(collatorRounds: SubqueryCollatorDataResponse.HistoryElements(nodes: [])) }
        }

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let strongSelf = self else {
                throw CommonError.internal
            }

            let ids = try? idsClosure()
            let idsFilter = (ids?.compactMap { $0.toHex(includePrefix: true) }) ?? []

            let queryString = strongSelf.prepareCollatorsAprQuery(collatorIds: idsFilter)

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

        let resultFactory = AnyNetworkResultFactory<SubqueryCollatorDataResponse> { data in
            var nodes: [SubqueryCollatorData] = []

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let collatorRounds = data["collatorRounds"] as? [String: Any],
               let nodesJson = collatorRounds["nodes"] as? [[String: Any]] {
                for nodeJson in nodesJson {
                    if let collatorId = nodeJson["collatorId"] as? String, let apr = nodeJson["apr"] as? Double {
                        let data = SubqueryCollatorData(collatorId: collatorId, apr: apr)
                        nodes.append(data)
                    }
                }
            }

            let response = SubqueryResponse.data(SubqueryCollatorDataResponse(collatorRounds: SubqueryCollatorDataResponse.HistoryElements(nodes: nodes)))

//            let response = try JSONDecoder().decode(
//                SubqueryResponse<SubqueryCollatorDataResponse>.self,
//                from: data
//            )
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

    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryRewardOrSlashData> {
        guard let url = url else {
            return ClosureOperation { SubqueryRewardOrSlashData(historyElements: SubqueryRewardOrSlashData.HistoryElements(nodes: [])) }
        }

        let queryString = prepareQueryForAddress(
            address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory {
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

        let resultFactory = AnyNetworkResultFactory<SubqueryRewardOrSlashData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryRewardOrSlashData>.self,
                from: data
            )

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
