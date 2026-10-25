import AuthenticationServices
import Foundation

@available(iOS 18.0, *)
@MainActor
protocol PasskeyBackupPRFAuthorizationSession: AnyObject {
    func start()
    func cancel()
}

/// A separate local path; the legacy string-only executor and client remain unchanged.
@available(iOS 18.0, *)
@MainActor
final class ASPasskeyBackupPRFExecutor {
    typealias Completion = (Result<PasskeyBackupPRFCeremonyResult, Error>) -> Void
    typealias SessionFactory = (
        ASAuthorizationRequest, PasskeyBackupPRFContext, @escaping Completion
    ) -> PasskeyBackupPRFAuthorizationSession

    private struct Active {
        let id: UUID
        let session: PasskeyBackupPRFAuthorizationSession
        let continuation: CheckedContinuation<PasskeyBackupPRFCeremonyResult, Error>
    }

    private let sessionFactory: SessionFactory
    private let isReleaseEnabled: Bool
    private var active: Active?

    convenience init(presentationAnchor: @escaping () -> ASPresentationAnchor) {
        self.init { request, context, completion in
            NativePasskeyBackupPRFSession(
                request: request,
                context: context,
                presentationAnchor: presentationAnchor,
                completion: completion
            )
        }
    }

    /// Dependency injection is for deterministic tests. Production uses the compiled false default.
    init(
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        sessionFactory: @escaping SessionFactory
    ) {
        self.isReleaseEnabled = isReleaseEnabled
        self.sessionFactory = sessionFactory
    }

    func performRegistration(
        _ pending: PendingPasskeyBackupRegistration, prfSalt: Data
    ) async throws -> PasskeyBackupPRFCeremonyResult {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let (request, context) = try PasskeyBackupPRFRequestFactory.registration(pending, prfSalt: prfSalt)
        return try await authorize(request: request, context: context)
    }

    func performAssertion(_ context: PasskeyBackupPRFContext) async throws -> PasskeyBackupPRFCeremonyResult {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        return try await authorize(request: PasskeyBackupPRFRequestFactory.assertion(context), context: context)
    }

    private func authorize(
        request: ASAuthorizationRequest, context: PasskeyBackupPRFContext
    ) async throws -> PasskeyBackupPRFCeremonyResult {
        try Task.checkCancellation()
        guard active == nil else { throw PasskeyBackupError.ceremonyInProgress }
        let id = UUID()
        let result: PasskeyBackupPRFCeremonyResult = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: PasskeyBackupPRFError.cancelled)
                    return
                }
                let session = sessionFactory(request, context) { [weak self] result in
                    self?.finish(id: id, result: result)
                }
                active = Active(id: id, session: session, continuation: continuation)
                session.start()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(id: id, result: .failure(PasskeyBackupPRFError.cancelled), cancel: true)
            }
        }
        try Task.checkCancellation()
        return result
    }

    private func finish(
        id: UUID, result: Result<PasskeyBackupPRFCeremonyResult, Error>, cancel: Bool = false
    ) {
        guard let current = active, current.id == id else { return }
        active = nil
        if cancel { current.session.cancel() }
        current.continuation.resume(with: result)
    }
}

@available(iOS 18.0, *)
@MainActor
private final class NativePasskeyBackupPRFSession: NSObject, PasskeyBackupPRFAuthorizationSession,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let controller: ASAuthorizationController
    private let context: PasskeyBackupPRFContext
    private let anchor: () -> ASPresentationAnchor
    private var completion: ASPasskeyBackupPRFExecutor.Completion?

    init(
        request: ASAuthorizationRequest, context: PasskeyBackupPRFContext,
        presentationAnchor: @escaping () -> ASPresentationAnchor,
        completion: @escaping ASPasskeyBackupPRFExecutor.Completion
    ) {
        controller = ASAuthorizationController(authorizationRequests: [request])
        self.context = context
        anchor = presentationAnchor
        self.completion = completion
        super.init()
        controller.delegate = self
        controller.presentationContextProvider = self
    }

    func start() { controller.performRequests() }
    func cancel() {
        completion = nil
        controller.cancel()
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor { anchor() }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard controller === self.controller else { return }
        do {
            let result: PasskeyBackupPRFCeremonyResult
            switch (context.kind, authorization.credential) {
            case let (.registration, credential as ASAuthorizationPlatformPublicKeyCredentialRegistration):
                guard let attestation = credential.rawAttestationObject else {
                    throw PasskeyBackupPRFError.unexpectedCredential
                }
                result = try .registration(
                    context: context, credentialID: credential.credentialID,
                    clientDataJSON: credential.rawClientDataJSON, attestationObject: attestation, prf: credential.prf
                )
            case let (.assertion, credential as ASAuthorizationPlatformPublicKeyCredentialAssertion):
                result = try .assertion(
                    context: context, credentialID: credential.credentialID,
                    clientDataJSON: credential.rawClientDataJSON, authenticatorData: credential.rawAuthenticatorData,
                    signature: credential.signature, userHandle: credential.userID as Data?, prf: credential.prf
                )
            default:
                throw PasskeyBackupPRFError.unexpectedCredential
            }
            finish(.success(result))
        } catch {
            finish(.failure(PasskeyBackupPRFError.unexpectedCredential))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard controller === self.controller else { return }
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? PasskeyBackupPRFError.cancelled : .ceremonyFailed))
    }

    private func finish(_ result: Result<PasskeyBackupPRFCeremonyResult, Error>) {
        let callback = completion
        completion = nil
        callback?(result)
    }
}
