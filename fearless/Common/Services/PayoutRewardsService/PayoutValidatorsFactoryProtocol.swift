import Foundation
import RobinHood

protocol PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure: @escaping () throws -> EraRange?
    ) -> CompoundOperationWrapper<[AccountId]>
}
