import Foundation

final class ErrorConditionViolation: DataValidating {
    let preservesCondition: () -> Bool
    let onError: () -> Void

    init(
        onError: @escaping () -> Void,
        preservesCondition: @escaping () -> Bool
    ) {
        self.preservesCondition = preservesCondition
        self.onError = onError
    }

    func validate(notifying _: DataValidatingDelegate) -> DataValidationProblem? {
        if preservesCondition() {
            return nil
        }

        onError()

        return .error
    }
}
