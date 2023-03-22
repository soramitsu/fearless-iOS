enum PhoneVerificationState {
    case enabled
    case disabled(errorMessage: String?)
    case inProgress
}
