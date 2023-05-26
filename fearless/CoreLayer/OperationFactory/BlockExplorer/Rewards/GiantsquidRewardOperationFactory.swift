import Foundation
import RobinHood
import SSFUtils
import SoraFoundation

enum GiantsquidRewardOperationFactoryError: Error {
    case urlMissing
    case stakingTypeUnsupported
    case incorrectAddress
}

final class GiantsquidRewardOperationFactory {
    private let url: URL?
    private let chain: ChainModel

    init(url: URL?, chain: ChainModel) {
        self.url = url
        self.chain = chain
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
                  stakingRewards(orderBy: timestamp_DESC, where: {account: {publicKey_eq: \"\(address)\"},  \(timestampFilter)}) {
                    id
                    amount
                    blockNumber
                    era
                    timestamp
                  }
                }
        """
    }
}

extension GiantsquidRewardOperationFactory: RewardOperationFactoryProtocol {
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
        address _: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
        BaseOperation.createWithError(GiantsquidRewardOperationFactoryError.stakingTypeUnsupported)
    }

    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardOrSlashResponse> {
        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let strongSelf = self else {
                throw CommonError.internal
            }

            let accountId = try AddressFactory.accountId(from: address, chain: strongSelf.chain).toHex(includePrefix: true)
            let queryString = strongSelf.prepareHistoryRequestForAddress(
                accountId,
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp
            )

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
                SubqueryResponse<GiantsquidResponseData>.self,
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
