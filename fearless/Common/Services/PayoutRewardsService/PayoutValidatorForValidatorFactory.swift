import Foundation
import RobinHood
import IrohaCrypto

final class PayoutValidatorsForValidatorFactory: PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(for address: AccountAddress) -> CompoundOperationWrapper<[AccountId]> {
        let operation = ClosureOperation<[AccountId]> {
            let accountId = try SS58AddressFactory().accountId(from: address)
            return [accountId]
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
