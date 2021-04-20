import Foundation
import RobinHood

protocol PayoutRewardsServiceProtocol {
    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<PayoutsInfo>
}

enum PayoutRewardsServiceError: Error {
    case unknown
}
