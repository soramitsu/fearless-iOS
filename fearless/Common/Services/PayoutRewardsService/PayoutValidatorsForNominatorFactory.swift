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
        let source = SubqueryEraStakersInfoSource(url: subqueryURL, address: address)
        let operation = source.fetch {
            try? historyRangeOperation.extractNoCancellableResultData()
        }
        operation.addDependency(operations: [historyRangeOperation])

        let mergeOperation = ClosureOperation<[AccountId]> {
            let erasInfo = try operation.targetOperation.extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()
            return erasInfo
                .compactMap { validatorInfo -> AccountAddress? in
                    let contains = validatorInfo.others.contains(where: { $0.who == address })
                    return contains ? validatorInfo.address : nil
                }
                .compactMap { accountAddress -> AccountId? in
                    try? addressFactory.accountId(from: accountAddress)
                }
        }
        operation.allOperations.forEach { mergeOperation.addDependency($0) }
        let dependencies = operation.allOperations
        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
