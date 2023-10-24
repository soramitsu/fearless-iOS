import Foundation
import RobinHood
import SSFUtils
import SoraFoundation
import SSFModels

enum SoraRewardOperationFactoryError: Error {
    case urlMissing
    case stakingTypeUnsupported
    case incorrectAddress
}

final class SoraRewardOperationFactory {
    private let url: URL?
    private let chain: ChainModel

    init(url: URL?, chain: ChainModel) {
        self.url = url
        self.chain = chain
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
                  stakingRewards(orderBy: timestamp_DESC, where: {payee_containsInsensitive: \"\(address)\",  \(timestampFilter)}) {
                    id
                    amount
                    timestamp
                  }
                }
        """
    }
}

extension SoraRewardOperationFactory: RewardOperationFactoryProtocol {
    func createLastRoundOperation() -> BaseOperation<String> {
        BaseOperation.createWithError(SoraRewardOperationFactoryError.stakingTypeUnsupported)
    }

    func createAprOperation(
        for _: @escaping () throws -> [AccountId],
        dependingOn _: BaseOperation<String>
    ) -> BaseOperation<CollatorAprResponse> {
        BaseOperation.createWithError(SoraRewardOperationFactoryError.stakingTypeUnsupported)
    }

    func createDelegatorRewardsOperation(
        address _: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
        BaseOperation.createWithError(SoraRewardOperationFactoryError.stakingTypeUnsupported)
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

            let queryString = strongSelf.prepareHistoryRequestForAddress(
                address,
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
