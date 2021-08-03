import Foundation
import RobinHood

protocol PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(for address: AccountAddress) -> CompoundOperationWrapper<[AccountId]>
}
