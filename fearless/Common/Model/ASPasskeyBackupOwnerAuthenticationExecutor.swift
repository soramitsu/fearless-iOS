import AuthenticationServices
import Foundation

@available(iOS 18.0, *)
@MainActor
protocol PasskeyBackupOwnerAuthenticationExecutor {
    func perform(
        challenge: PasskeyOwnerAuthChallenge
    ) async throws -> PasskeyBackupOwnerPublicAssertion
}

@available(iOS 18.0, *)
enum PasskeyOwnerAuthRequestFactory {
    static func assertion(
        _ challenge: PasskeyOwnerAuthChallenge
    ) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: PasskeyBackupContract.PASSKEY_RP_ID
        )
        let request = provider.createCredentialAssertionRequest(challenge: challenge.challenge)
        request.allowedCredentials = []
        request.userVerificationPreference = .required
        return request
    }
}

/// A delayed cancellation may complete only the ceremony that installed it.
struct PasskeyOwnerAuthAttemptGate {
    private(set) var activeID: UUID?

    mutating func begin(_ id: UUID) -> Bool {
        guard activeID == nil else { return false }
        activeID = id
        return true
    }

    mutating func finish(_ id: UUID) -> Bool {
        guard activeID == id else { return false }
        activeID = nil
        return true
    }
}

/// A separate discoverable ceremony produces only public WebAuthn assertion fields.
/// The PRF-producing directed assertion remains a later, local-only recovery step.
@available(iOS 18.0, *)
@MainActor
final class ASPasskeyOwnerAuthExecutor: NSObject,
    PasskeyBackupOwnerAuthenticationExecutor,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private let presentationAnchor: () -> ASPresentationAnchor
    private let isReleaseEnabled: Bool
    private var controller: ASAuthorizationController?
    private var continuation: CheckedContinuation<PasskeyBackupOwnerPublicAssertion, Error>?
    private var attemptGate = PasskeyOwnerAuthAttemptGate()

    init(
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        presentationAnchor: @escaping () -> ASPresentationAnchor
    ) {
        self.isReleaseEnabled = isReleaseEnabled
        self.presentationAnchor = presentationAnchor
    }

    func perform(
        challenge: PasskeyOwnerAuthChallenge
    ) async throws -> PasskeyBackupOwnerPublicAssertion {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try Task.checkCancellation()
        guard continuation == nil else { throw PasskeyBackupError.ceremonyInProgress }
        let request = PasskeyOwnerAuthRequestFactory.assertion(challenge)
        let attemptID = UUID()
        let result: PasskeyBackupOwnerPublicAssertion = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: PasskeyBackupError.ceremonyCancelled)
                    return
                }
                guard attemptGate.begin(attemptID) else {
                    continuation.resume(throwing: PasskeyBackupError.ceremonyInProgress)
                    return
                }
                let active = ASAuthorizationController(authorizationRequests: [request])
                self.continuation = continuation
                controller = active
                active.delegate = self
                active.presentationContextProvider = self
                active.performRequests()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(PasskeyBackupError.ceremonyCancelled), attemptID: attemptID, cancel: true)
            }
        }
        try Task.checkCancellation()
        return result
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard controller === self.controller, let attemptID = attemptGate.activeID else { return }
        do {
            guard let credential = authorization.credential as?
                ASAuthorizationPlatformPublicKeyCredentialAssertion else {
                throw PasskeyBackupOwnerAuthenticationError.invalidAssertion
            }
            let assertion = try PasskeyBackupOwnerPublicAssertion(
                credentialID: credential.credentialID,
                clientDataJSON: credential.rawClientDataJSON,
                authenticatorData: credential.rawAuthenticatorData,
                signature: credential.signature,
                userHandle: credential.userID
            )
            finish(.success(assertion), attemptID: attemptID)
        } catch {
            finish(.failure(PasskeyBackupOwnerAuthenticationError.invalidAssertion), attemptID: attemptID)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard controller === self.controller, let attemptID = attemptGate.activeID else { return }
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? PasskeyBackupError.ceremonyCancelled :
                PasskeyBackupOwnerAuthenticationError.invalidAssertion), attemptID: attemptID)
    }

    private func finish(
        _ result: Result<PasskeyBackupOwnerPublicAssertion, Error>,
        attemptID: UUID, cancel: Bool = false
    ) {
        guard let continuation, attemptGate.finish(attemptID) else { return }
        let active = controller
        self.continuation = nil
        controller = nil
        if cancel {
            active?.cancel()
        }
        continuation.resume(with: result)
    }
}

@available(iOS 18.0, *)
@MainActor
final class PasskeyOwnerAuthCoordinator {
    private let source: PasskeyBackupOwnerAuthenticationSource
    private let executor: PasskeyBackupOwnerAuthenticationExecutor
    private let isReleaseEnabled: Bool

    init(
        source: PasskeyBackupOwnerAuthenticationSource,
        executor: PasskeyBackupOwnerAuthenticationExecutor,
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled
    ) {
        self.source = source
        self.executor = executor
        self.isReleaseEnabled = isReleaseEnabled
    }

    func authenticate() async throws -> PasskeyBackupOwnerSession {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try Task.checkCancellation()
        let challenge = try await source.begin()
        let assertion = try await executor.perform(challenge: challenge)
        try Task.checkCancellation()
        return try await source.complete(challenge: challenge, assertion: assertion)
    }
}
