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

final class ErrorThrowingViolation: DataValidating {
    private let preservesCondition: () -> String?
    private let onError: (_ text: String) -> Void

    init(
        onError: @escaping (_ text: String) -> Void,
        preservesCondition: @escaping () -> String?
    ) {
        self.preservesCondition = preservesCondition
        self.onError = onError
    }

    func validate(notifying _: DataValidatingDelegate) -> DataValidationProblem? {
        guard let textError = preservesCondition() else {
            return nil
        }

        onError(textError)

        return .error
    }
}
