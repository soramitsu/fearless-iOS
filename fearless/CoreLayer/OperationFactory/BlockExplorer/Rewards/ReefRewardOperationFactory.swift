import Foundation
import RobinHood
import SSFUtils
import SoraFoundation
import SSFModels

enum ReefRewardOperationFactoryError: Error {
    case urlMissing
    case stakingTypeUnsupported
    case incorrectAddress
}

final class ReefRewardOperationFactory {
    private let url: URL?
    private let chain: ChainModel

    init(url: URL?, chain: ChainModel) {
        self.url = url
        self.chain = chain
    }

    private func prepareLastRoundsQuery() -> String {
        ""
    }

    private func prepareCollatorsAprQuery(collatorIds _: [String], roundId _: String) -> String {
        ""
    }

    private func prepareHistoryRequestForAddress(
        _ address: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) -> String {
        """
        query MyQuery {
                stakings(limit: 20, where: {signer: {id_eq: "\(address)"}}, orderBy: timestamp_DESC) {
                    type
                    amount
                    timestamp
                    id
                    signer {
                      id
                    }
                    event {
                      data
                    }
                  }
        }
        """
    }
}

extension ReefRewardOperationFactory: RewardOperationFactoryProtocol {
    func createLastRoundOperation() -> BaseOperation<String> {
        BaseOperation.createWithError(GiantsquidRewardOperationFactoryError.stakingTypeUnsupported)
    }

    func createAprOperation(
        for _: @escaping () throws -> [AccountId],
        dependingOn _: BaseOperation<String>
    ) -> BaseOperation<CollatorAprResponse> {
        BaseOperation.createWithError(GiantsquidRewardOperationFactoryError.stakingTypeUnsupported)
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
                GraphQLResponse<ReefResponseData>.self,
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
