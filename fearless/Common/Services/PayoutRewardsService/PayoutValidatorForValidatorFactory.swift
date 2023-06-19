import Foundation
import RobinHood
import IrohaCrypto
import SSFModels

final class PayoutValidatorsForValidatorFactory: PayoutValidatorsFactoryProtocol {
    private let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure _: @escaping () throws -> EraRange?
    ) -> CompoundOperationWrapper<[AccountId]> {
        let operation = ClosureOperation<[AccountId]> { [weak self] in
            guard let strongSelf = self else {
                return []
            }

            let accountId = try AddressFactory.accountId(
                from: address,
                chain: strongSelf.chainAsset.chain
            )
            return [accountId]
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
