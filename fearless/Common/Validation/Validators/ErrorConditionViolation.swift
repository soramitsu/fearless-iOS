import Foundation

final class ErrorConditionViolation: DataValidating {
    let checkCondition: () -> Bool
    let onError: () -> Void

    init(
        onError: @escaping () -> Void,
        checkCondition: @escaping () -> Bool
    ) {
        self.checkCondition = checkCondition
        self.onError = onError
    }

    func validate(notifying _: DataValidatingDelegate) -> DataValidationProblem? {
        if checkCondition() {
            return nil
        }

        onError()

        return .error
    }
}
