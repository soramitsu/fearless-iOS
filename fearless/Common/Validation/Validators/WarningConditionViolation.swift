import Foundation

final class WarningConditionViolation: DataValidating {
    let checkCondition: () -> Bool
    let onWarning: (DataValidatingDelegate) -> Void

    init(
        onWarning: @escaping (DataValidatingDelegate) -> Void,
        checkCondition: @escaping () -> Bool
    ) {
        self.checkCondition = checkCondition
        self.onWarning = onWarning
    }

    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem? {
        if checkCondition() {
            return nil
        }

        onWarning(delegate)

        return .warning
    }
}
