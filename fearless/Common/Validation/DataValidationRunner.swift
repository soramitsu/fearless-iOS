import Foundation

final class DataValidationRunner {
    let validators: [DataValidating]

    private var lastIndex: Int = 0
    private var savedClosure: DataValidationRunnerCompletion?

    init(validators: [DataValidating]) {
        self.validators = validators
    }

    deinit {
        lastIndex = 0
    }

    private func runValidation(from startIndex: Int) {
        for index in startIndex ..< validators.count {
            if let problem = validators[index].validate(notifying: self) {
                switch problem {
                case .warning:
                    lastIndex = index
                    return
                case .error:
                    return
                }
            }
        }

        savedClosure?()
    }
}

extension DataValidationRunner: DataValidationRunnerProtocol {
    func runValidation(notifyingOnSuccess closure: @escaping DataValidationRunnerCompletion) {
        savedClosure = closure
        runValidation(from: 0)
    }
}

extension DataValidationRunner: DataValidatingDelegate {
    func didCompleteWarningHandling() {
        runValidation(from: lastIndex + 1)
    }
}
