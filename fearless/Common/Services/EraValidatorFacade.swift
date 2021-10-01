import Foundation
import RobinHood

// TODO: Remove after refactoring
final class EraValidatorFacade {
    static let sharedService = MockEraValidatorService()
}

final class MockEraValidatorService: EraValidatorServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        BaseOperation.createWithError(BaseOperationError.parentOperationCancelled)
    }

    func setup() {}

    func throttle() {}
}
