import Foundation
import RobinHood
import FearlessUtils

protocol SubqueryHistoryOperationFactoryProtocol {
    func createOperation(
        address: String,
        count: Int,
        cursor: String?
    ) -> BaseOperation<SubqueryHistoryData>
}

final class SubqueryHistoryOperationFactory {
    let url: URL
    let filters: [WalletTransactionHistoryFilter]

    init(url: URL, filters: [WalletTransactionHistoryFilter]) {
        self.url = url
        self.filters = filters
    }

    private func prepareExtrinsicInclusionFilter() -> String {
        """
        {
          or: [
            {
                  extrinsic: {isNull: true}
            },
            {
              not: {
                and: [
                    {
                      extrinsic: { contains: {module: "balances"} } ,
                        or: [
                         { extrinsic: {contains: {call: "transfer"} } },
                         { extrinsic: {contains: {call: "transferKeepAlive"} } },
                         { extrinsic: {contains: {call: "forceTransfer"} } },
                      ]
                    }
                ]
               }
            }
          ]
        }
        """
    }

    private func prepareFilter() -> String {
        var filterStrings: [String] = []

        if !filters.contains(where: { $0.type == .other && $0.selected }) {
            filterStrings.append("{extrinsic: { isNull: true }}")
        }

        if !filters.contains(where: { $0.type == .reward && $0.selected }) {
            filterStrings.append("{reward: { isNull: true }}")
        }

        if !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append("{transfer: { isNull: true }}")
        }

        return filterStrings.joined(separator: ",")
    }

    private func prepareQueryForAddress(_ address: String, count: Int, cursor: String?) -> String {
        let after = cursor.map { "\"\($0)\"" } ?? "null"
        let filterString = prepareFilter()
        return """
        {
            historyElements(
                 after: \(after),
                 first: \(count),
                 orderBy: TIMESTAMP_DESC,
                 filter: {
                     address: { equalTo: \"\(address)\"},
                     and: [
                        \(filterString)
                     ]
                 }
             ) {
                 pageInfo {
                     startCursor,
                     endCursor
                 },
                 nodes {
                     id
                     timestamp
                     address
                     reward
                     extrinsic
                     transfer
                 }
             }
        }
        """
    }
}

extension SubqueryHistoryOperationFactory: SubqueryHistoryOperationFactoryProtocol {
    func createOperation(
        address: String,
        count: Int,
        cursor: String?
    ) -> BaseOperation<SubqueryHistoryData> {
        let queryString = prepareQueryForAddress(address, count: count, cursor: cursor)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryHistoryData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryHistoryData>.self,
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
