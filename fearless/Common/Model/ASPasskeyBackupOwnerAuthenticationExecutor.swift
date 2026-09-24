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
        let result: PasskeyBackupOwnerPublicAssertion = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: PasskeyBackupError.ceremonyCancelled)
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
                self?.finish(.failure(PasskeyBackupError.ceremonyCancelled), cancel: true)
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
        guard controller === self.controller else { return }
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
            finish(.success(assertion))
        } catch {
            finish(.failure(PasskeyBackupOwnerAuthenticationError.invalidAssertion))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard controller === self.controller else { return }
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? PasskeyBackupError.ceremonyCancelled :
                PasskeyBackupOwnerAuthenticationError.invalidAssertion))
    }

    private func finish(
        _ result: Result<PasskeyBackupOwnerPublicAssertion, Error>, cancel: Bool = false
    ) {
        guard let continuation else { return }
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
