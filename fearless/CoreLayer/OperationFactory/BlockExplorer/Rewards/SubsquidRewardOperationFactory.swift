import Foundation
import RobinHood
import SSFUtils
import SSFModels

enum ArrosquidRewardOperationFactoryError: Error {
    case urlMissing
}

final class ArrowsquidRewardOperationFactory {
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    private func prepareTimestampFilter(
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        var bounds = [String]()
        if let startTimestamp {
            bounds.append("timestamp_gte: \(startTimestamp)")
        }
        if let endTimestamp {
            bounds.append("timestamp_lte: \(endTimestamp)")
        }

        guard !bounds.isEmpty else {
            return ""
        }

        return "AND: { \(bounds.joined(separator: ", ")) },"
    }

    private func prepareDelegatorHistoryRequest(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter = prepareTimestampFilter(
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        return """
        query MyQuery {
          historyElements(
            orderBy: timestamp_DESC,
            where: { address_eq: "\(address)", \(timestampFilter) reward_isNull: false }
          ) {
            id
            blockHeight
            timestamp
            address
            reward {
              amount
              era
              stash
              validator
            }
          }
        }
        """
    }

    private func prepareHistoryRequestForAddress(
        _ address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter = prepareTimestampFilter(
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        return """
        query MyQuery {
          historyElements(
            orderBy: timestamp_DESC,
            where: { address_eq: "\(address)", \(timestampFilter) reward_isNull: false }
          ) {
            timestamp
                id
                address
                reward {
                  amount
                  era
                  stash
                  validator
                }
          }
        }
        """
    }
}

extension ArrowsquidRewardOperationFactory: RewardOperationFactoryProtocol {
    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
        guard RewardHistoryRequestValidator.isValid(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            maximumTimestamp: Int64(Int32.max)
        ) else {
            return BaseOperation.createWithError(RewardHistoryRequestError.invalidParameters)
        }

        let queryString = prepareDelegatorHistoryRequest(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
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

        let resultFactory = AnyNetworkResultFactory<RewardHistoryResponseProtocol> { data in
            do {
                let response = try JSONDecoder().decode(
                    GraphQLResponse<SubsquidDelegatorRewardsData>.self,
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

    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardOrSlashResponse> {
        guard RewardHistoryRequestValidator.isValid(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            maximumTimestamp: Int64(Int32.max)
        ) else {
            return BaseOperation.createWithError(RewardHistoryRequestError.invalidParameters)
        }

        let queryString = prepareHistoryRequestForAddress(
            address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
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

        let resultFactory = AnyNetworkResultFactory<RewardOrSlashResponse> { data in
            let response = try JSONDecoder().decode(
                GraphQLResponse<ArrowsquidHistoryResponse>.self,
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
