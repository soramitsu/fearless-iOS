enum VerificationState {
    case enabled
    case disabled(errorMessage: String?)
    case inProgress
}
