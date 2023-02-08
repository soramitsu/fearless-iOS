import Foundation
import RobinHood
import FearlessUtils
import SoraFoundation

enum SubsquidRewardOperationFactoryError: Error {
    case urlMissing
}

final class SubsquidRewardOperationFactory {
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    private func prepareLastRoundsQuery() -> String {
        """
        query MyQuery {
          rounds(orderBy: index_DESC, limit: 1) {
            id
          }
        }
        """
    }

    private func prepareCollatorsAprQuery(collatorIds _: [String], roundId _: String) -> String {
        """
        query MyQuery {
          stakers(where: {role_eq: "collator"}) {
            apr24h
            stashId
          }
        }
        """
    }

    private func prepareDelegatorHistoryRequest(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            let locale = LocalizationManager.shared.selectedLocale
            guard startTimestamp != nil || endTimestamp != nil else { return "" }

            var result = "AND: {"
            let dateFormatter = DateFormatter.suibsquidInputDate.value(for: locale)
            if let startTimestamp = startTimestamp {
                let startDate = Date(timeIntervalSince1970: TimeInterval(startTimestamp))
                let startDateString = dateFormatter.string(from: startDate)
                result.append("timestamp_gte:\"\(startDateString)\"")
            }

            if let endTimestamp = endTimestamp {
                let endDate = Date(timeIntervalSince1970: TimeInterval(endTimestamp))
                let endDateString = dateFormatter.string(from: endDate)
                result.append("timestamp_lte:\"\(endDateString)\"")
            }
            result.append("}")
            return result
        }()

        return """
        query MyQuery {
          rewards(orderBy: timestamp_DESC, where: {accountId_containsInsensitive: "\(address)", \(timestampFilter)}) {
            id
            accountId
            amount
            blockNumber
            round
            timestamp
          }
        }

        """
    }

    private func prepareHistoryRequestForAddress(
        _ address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            let locale = LocalizationManager.shared.selectedLocale
            guard startTimestamp != nil || endTimestamp != nil else { return "" }

            var result = "AND: {"
            let dateFormatter = DateFormatter.suibsquidInputDate.value(for: locale)
            if let startTimestamp = startTimestamp {
                let startDate = Date(timeIntervalSince1970: TimeInterval(startTimestamp))
                let startDateString = dateFormatter.string(from: startDate)
                result.append("timestamp_gte:\"\(startDateString)\"")
            }

            if let endTimestamp = endTimestamp {
                let endDate = Date(timeIntervalSince1970: TimeInterval(endTimestamp))
                let endDateString = dateFormatter.string(from: endDate)
                result.append("timestamp_lte:\"\(endDateString)\"")
            }
            result.append("}")
            return result
        }()

        return """
        query MyQuery {
          rewards(orderBy: timestamp_DESC, where: {accountId_containsInsensitive: "\(address)", \(timestampFilter)}) {
            id
            accountId
            amount
            blockNumber
            extrinsicHash
            round
            timestamp
          }
        }
        """
    }
}

extension SubsquidRewardOperationFactory: RewardOperationFactoryProtocol {
    func createLastRoundOperation() -> BaseOperation<String> {
        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            guard let strongSelf = self else {
                throw CommonError.internal
            }

            let queryString = strongSelf.prepareLastRoundsQuery()

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

        let resultFactory = AnyNetworkResultFactory<String> { data in
            var roundId: String = ""

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let collatorRounds = data["rounds"] as? [[String: Any]] {
                for nodeJson in collatorRounds {
                    if let foundRoundId = nodeJson["index"] as? UInt32 {
                        roundId = "\(foundRoundId - 1)"
                    }
                }
            }

            return roundId
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func createAprOperation(
        for accountIdsClosure: @escaping () throws -> [AccountId],
        dependingOn roundIdOperation: BaseOperation<String>
    ) -> BaseOperation<CollatorAprResponse> {
        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            guard let strongSelf = self else {
                throw CommonError.internal
            }

            let roundId = (try? roundIdOperation.extractNoCancellableResultData()) ?? ""

            let ids = try? accountIdsClosure()
            let idsFilter = (ids?.compactMap { $0.toHex(includePrefix: true) }) ?? []

            let queryString = strongSelf.prepareCollatorsAprQuery(collatorIds: idsFilter, roundId: roundId)

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

        let resultFactory = AnyNetworkResultFactory<CollatorAprResponse> { data in
            do {
                let response = try JSONDecoder().decode(
                    SubqueryResponse<SubsquidCollatorAprResponse>.self,
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

    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
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
                    SubqueryResponse<SubsquidDelegatorRewardsData>.self,
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
    ) -> BaseOperation<SubqueryRewardOrSlashData> {
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
