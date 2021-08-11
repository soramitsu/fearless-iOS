import Foundation
import RobinHood
import FearlessUtils
import IrohaCrypto

final class PayoutValidatorsForNominatorFactory {
    let chain: Chain
    let subqueryURL: URL

    init(
        chain: Chain,
        subqueryURL: URL
    ) {
        self.chain = chain
        self.subqueryURL = subqueryURL
    }
}

extension PayoutValidatorsForNominatorFactory: PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        dependingOn historyRangeOperation: BaseOperation<ChainHistoryRange>
    ) -> CompoundOperationWrapper<[AccountId]> {
        let source = SQEraStakersInfoSource(url: subqueryURL, address: address)
        let operation = source.fetch {
            try? historyRangeOperation.extractNoCancellableResultData()
        }
        operation.addDependency(operations: [historyRangeOperation])

        return operation
    }
}

// TODO: move to /Common/Network/Subquery when Analytics will be done
struct SQEraValidatorInfo {
    let address: String
    let era: String
    let total: String
    let own: String
    let others: [SQIndividualExposure]

    init?(from json: JSON) {
        guard
            let era = json.era?.stringValue,
            let address = json.address?.stringValue,
            let total = json.total?.stringValue,
            let own = json.own?.stringValue,
            let others = json.others?.arrayValue?.compactMap({ SQIndividualExposure(from: $0) })
        else { return nil }

        self.era = era
        self.address = address
        self.total = total
        self.own = own
        self.others = others
    }
}

struct SQIndividualExposure {
    let who: String
    let value: String

    init?(from json: JSON) {
        guard
            let who = json.who?.stringValue,
            let value = json.value?.stringValue
        else { return nil }
        self.who = who
        self.value = value
    }
}

// TODO: move to /Common/DataProvider/Subquery when Analytics will be done
final class SQEraStakersInfoSource {
    let url: URL
    let address: AccountAddress

    init(url: URL, address: AccountAddress) {
        self.url = url
        self.address = address
    }

    func fetch(historyRange: @escaping () -> ChainHistoryRange?) -> CompoundOperationWrapper<[AccountId]> {
        let requestFactory = createRequestFactory(historyRange: historyRange)
        let resultFactory = createResultFactory()

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func createRequestFactory(
        historyRange: @escaping () -> ChainHistoryRange?
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let erasRange = historyRange()?.erasRange
            let params = self.requestParams(accountAddress: self.address, erasRange: erasRange)
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }
    }

    private func createResultFactory() -> AnyNetworkResultFactory<[AccountId]> {
        AnyNetworkResultFactory<[AccountId]> { data in
            guard
                let resultData = try? JSONDecoder().decode(JSON.self, from: data),
                let nodes = resultData.data?.query?.eraValidatorInfos?.nodes?.arrayValue
            else { return [] }

            let addressFactory = SS58AddressFactory()
            let validators = nodes
                .compactMap { SQEraValidatorInfo(from: $0) }
                .compactMap { validatorInfo -> AccountAddress? in
                    let contains = validatorInfo.others.contains(where: { $0.who == self.address })
                    return contains ? validatorInfo.address : nil
                }
                .compactMap { accountAddress -> AccountId? in
                    try? addressFactory.accountId(from: accountAddress)
                }

            return validators
        }
    }

    private func requestParams(accountAddress: AccountAddress, erasRange: [EraIndex]?) -> String {
        let eraFilter: String = {
            guard let range = erasRange, range.count >= 2 else { return "" }
            return "era:{greaterThanOrEqualTo: \(range.first!), lessThanOrEqualTo: \(range.last!)},"
        }()

        return """
        {
          query {
            eraValidatorInfos(
              filter:{
                \(eraFilter)
                others:{contains:[{who:\"\(accountAddress)\"}]}
              }
            ) {
              nodes {
                id
                address
                era
                total
                own
                others
              }
            }
          }
        }
        """
    }
}
