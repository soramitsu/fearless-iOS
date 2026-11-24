import Foundation

/// How a screen-authorization PIN ended.
enum ScreenAuthorizationOutcome: Equatable {
    /// The PIN, or a biometric the PIN holder trusted, was accepted.
    case authorized
    /// The user cancelled, the check failed, or the screen was closed.
    case declined
    /// The app went to the background while the PIN was asked: the user gave no answer.
    case unanswered

    var isAuthorized: Bool { self == .authorized }
}

protocol ScreenAuthorizationWireframeProtocol: AnyObject {
    func showAuthorizationCompletion(with result: Bool)
    /// A wireframe that tells a refusal from no answer implements this; the others hear `false` for both.
    func showAuthorizationCompletion(outcome: ScreenAuthorizationOutcome)
}

extension ScreenAuthorizationWireframeProtocol {
    func showAuthorizationCompletion(outcome: ScreenAuthorizationOutcome) {
        showAuthorizationCompletion(with: outcome.isAuthorized)
    }
}
