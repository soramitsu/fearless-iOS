import Foundation

final class WarningConditionViolation: DataValidating {
    let preservesCondition: () -> Bool
    let onWarning: (DataValidatingDelegate) -> Void

    init(
        onWarning: @escaping (DataValidatingDelegate) -> Void,
        preservesCondition: @escaping () -> Bool
    ) {
        self.preservesCondition = preservesCondition
        self.onWarning = onWarning
    }

    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem? {
        if preservesCondition() {
            return nil
        }

        onWarning(delegate)

        return .warning
    }
}
