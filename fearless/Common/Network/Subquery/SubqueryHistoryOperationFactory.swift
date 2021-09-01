import Foundation
import RobinHood
import FearlessUtils

final class SubqueryHistoryOperationFactory {
    let url: URL
    let filter: WalletHistoryFilter

    init(url: URL, filter: WalletHistoryFilter) {
        self.url = url
        self.filter = filter
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

        if filter.contains(.extrinsics) {
            filterStrings.append(prepareExtrinsicInclusionFilter())
        } else {
            filterStrings.append("{extrinsic: { isNull: true }}")
        }

        if !filter.contains(.rewardsAndSlashes) {
            filterStrings.append("{reward: { isNull: true }}")
        }

        if !filter.contains(.transfers) {
            filterStrings.append("{transfer: { isNull: true }}")
        }

        return filterStrings.joined(separator: ",")
    }

    private func prepareQueryForAddress(_ address: String, cursor: String?, count: Int) -> String {
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

extension SubqueryHistoryOperationFactory: WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(
        for context: TransactionHistoryContext,
        address: String,
        count: Int
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let queryString = prepareQueryForAddress(address, cursor: context.cursor, count: count)

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

        let resultFactory = AnyNetworkResultFactory<WalletRemoteHistoryData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryHistoryData>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                let pageInfo = response.historyElements.pageInfo
                let items = response.historyElements.nodes

                let context = TransactionHistoryContext(
                    cursor: pageInfo.endCursor,
                    isComplete: pageInfo.endCursor == nil
                )

                return WalletRemoteHistoryData(
                    historyItems: items,
                    context: context
                )
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
