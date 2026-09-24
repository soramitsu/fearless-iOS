import AuthenticationServices
import CryptoKit
import Foundation

/// This owner ceremony is deliberately separate from the legacy wallet-key challenge service.
/// Its WebAuthn user handle and challenge come from the owner authority, not a storage key.
@available(iOS 18.0, *)
struct PasskeyFirstOwnerPRFRequestContext: CustomStringConvertible, CustomReflectable {
    let challenge: PasskeyBackupFirstOwnerChallenge
    let prfSalt: Data

    init(challenge: PasskeyBackupFirstOwnerChallenge, prfSalt: Data) throws {
        guard prfSalt.count == 32 else { throw PasskeyBackupPRFError.invalidInput }
        self.challenge = challenge
        self.prfSalt = prfSalt
    }

    func requireSameChallenge(_ other: PasskeyBackupFirstOwnerChallenge) throws {
        guard challenge.ceremonyID == other.ceremonyID,
              challenge.challenge == other.challenge,
              challenge.ownerSubject == other.ownerSubject,
              challenge.backupNamespace == other.backupNamespace,
              challenge.userHandle == other.userHandle,
              challenge.expiresAtUnixSeconds == other.expiresAtUnixSeconds else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidRegistration
        }
    }

    var description: String {
        "PasskeyFirstOwnerPRFRequestContext(<redacted>)"
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

@available(iOS 18.0, *)
enum PasskeyFirstOwnerPRFRequestFactory {
    static func registration(
        context: PasskeyFirstOwnerPRFRequestContext
    ) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: PasskeyBackupContract.PASSKEY_RP_ID
        )
        let request = provider.createCredentialRegistrationRequest(
            challenge: context.challenge.challenge,
            name: "Fearless Wallet backup",
            userID: context.challenge.userHandle
        )
        request.displayName = "Fearless Wallet backup"
        request.userVerificationPreference = .required
        request.attestationPreference = .none
        request.prf = .inputValues(.saltInput1(context.prfSalt))
        return request
    }
}

/// Native output has two disjoint fields: public registration and device-local PRF.
/// The latter is never exposed until the owner authority verifies the exact registration.
@available(iOS 18.0, *)
@MainActor
final class PasskeyFirstOwnerPRFCeremonyResult: CustomStringConvertible, CustomReflectable {
    private enum State { case pending, completing, consumed }

    let context: PasskeyFirstOwnerPRFRequestContext
    let registration: PasskeyFirstOwnerRegistration
    private var output: SymmetricKey?
    private var state: State = .pending

    private init(
        context: PasskeyFirstOwnerPRFRequestContext,
        registration: PasskeyFirstOwnerRegistration,
        output: SymmetricKey
    ) {
        self.context = context
        self.registration = registration
        self.output = output
    }

    static func registration(
        context: PasskeyFirstOwnerPRFRequestContext,
        credentialID: Data, clientDataJSON: Data, attestationObject: Data,
        prf: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?
    ) throws -> PasskeyFirstOwnerPRFCeremonyResult {
        guard let prf, prf.isSupported, prf.second == nil,
              let first = prf.first, first.bitCount == 256 else {
            throw PasskeyBackupPRFError.missingOutput
        }
        let publicRegistration = try PasskeyFirstOwnerRegistration(
            credentialID: credentialID, clientDataJSON: clientDataJSON,
            attestationObject: attestationObject
        )
        try publicRegistration.validate(against: context.challenge)
        return Self(context: context, registration: publicRegistration, output: first)
    }

    /// A failed or ambiguous completion consumes this local ceremony. The caller must
    /// authenticate the new credential to reconcile a possible server commit.
    func complete(
        challenge: PasskeyBackupFirstOwnerChallenge,
        expectedIdentity: PasskeyBackupExpectedWalletIdentity,
        signer: PasskeyOwnerWalletSigner,
        attestor: PasskeyBackupFirstOwnerAppAttestor,
        using source: HTTPPasskeyOwnerBootstrapSource
    ) async throws -> PasskeyFirstOwnerVerifiedLocalPRF {
        guard case .pending = state, let output else { throw PasskeyBackupPRFError.invalidState }
        try context.requireSameChallenge(challenge)
        try registration.validate(against: challenge)
        state = .completing
        do {
            let session = try await source.complete(
                challenge: challenge, registration: registration,
                expectedIdentity: expectedIdentity, signer: signer, attestor: attestor
            )
            state = .consumed
            self.output = nil
            return PasskeyFirstOwnerVerifiedLocalPRF(
                session: session, credentialID: registration.credentialID,
                prfSalt: context.prfSalt, output: output
            )
        } catch {
            state = .consumed
            self.output = nil
            throw error
        }
    }

    fileprivate func discard() {
        state = .consumed
        output = nil
    }

    nonisolated var description: String {
        "PasskeyFirstOwnerPRFCeremonyResult(<redacted>)"
    }

    nonisolated var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

@available(iOS 18.0, *)
@MainActor
final class PasskeyFirstOwnerVerifiedLocalPRF: CustomStringConvertible, CustomReflectable {
    let session: PasskeyBackupOwnerSession
    let credentialID: Data
    let prfSalt: Data
    private var output: SymmetricKey?

    fileprivate init(session: PasskeyBackupOwnerSession, credentialID: Data, prfSalt: Data, output: SymmetricKey) {
        self.session = session
        self.credentialID = credentialID
        self.prfSalt = prfSalt
        self.output = output
    }

    func withOutput<T>(_ action: (Data) throws -> T) throws -> T {
        guard let output else { throw PasskeyBackupPRFError.invalidState }
        self.output = nil
        var bytes = output.withUnsafeBytes { Data($0) }
        defer { bytes.resetBytes(in: 0 ..< bytes.count) }
        return try action(bytes)
    }

    nonisolated var description: String {
        "PasskeyFirstOwnerVerifiedLocalPRF(<redacted>)"
    }

    nonisolated var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

/// This executor is compiled off in production and has no app-flow call site yet.
/// GPM selection and PRF interoperability require real-device qualification.
@available(iOS 18.0, *)
@MainActor
final class ASFirstOwnerPRFExecutor {
    typealias Completion = (Result<PasskeyFirstOwnerPRFCeremonyResult, Error>) -> Void
    typealias SessionFactory = (
        ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest,
        PasskeyFirstOwnerPRFRequestContext, @escaping Completion
    ) -> PasskeyBackupPRFAuthorizationSession

    private struct Active {
        let id: UUID
        let session: PasskeyBackupPRFAuthorizationSession
        let continuation: CheckedContinuation<PasskeyFirstOwnerPRFCeremonyResult, Error>
    }

    private let sessionFactory: SessionFactory
    private let isReleaseEnabled: Bool
    private let nowUnixSeconds: () -> Int64
    private var active: Active?

    convenience init(presentationAnchor: @escaping () -> ASPresentationAnchor) {
        self.init { request, context, completion in
            NativeFirstOwnerPRFSession(
                request: request, context: context,
                presentationAnchor: presentationAnchor, completion: completion
            )
        }
    }

    init(
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        nowUnixSeconds: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) },
        sessionFactory: @escaping SessionFactory
    ) {
        self.isReleaseEnabled = isReleaseEnabled
        self.nowUnixSeconds = nowUnixSeconds
        self.sessionFactory = sessionFactory
    }

    func performRegistration(
        challenge: PasskeyBackupFirstOwnerChallenge, prfSalt: Data
    ) async throws -> PasskeyFirstOwnerPRFCeremonyResult {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try Task.checkCancellation()
        try challenge.requireFresh(nowUnixSeconds: nowUnixSeconds())
        let context = try PasskeyFirstOwnerPRFRequestContext(challenge: challenge, prfSalt: prfSalt)
        guard active == nil else { throw PasskeyBackupError.ceremonyInProgress }
        let id = UUID()
        let request = PasskeyFirstOwnerPRFRequestFactory.registration(context: context)
        let result: PasskeyFirstOwnerPRFCeremonyResult = try await withTaskCancellationHandler {
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
        do {
            try Task.checkCancellation()
            try challenge.requireFresh(nowUnixSeconds: nowUnixSeconds())
            try result.context.requireSameChallenge(challenge)
            guard result.context.prfSalt == context.prfSalt else {
                throw PasskeyBackupPRFError.invalidInput
            }
            return result
        } catch {
            result.discard()
            throw error
        }
    }

    private func finish(
        id: UUID, result: Result<PasskeyFirstOwnerPRFCeremonyResult, Error>, cancel: Bool = false
    ) {
        guard let current = active, current.id == id else { return }
        active = nil
        if cancel {
            current.session.cancel()
        }
        current.continuation.resume(with: result)
    }
}

@available(iOS 18.0, *)
@MainActor
private final class NativeFirstOwnerPRFSession: NSObject,
    PasskeyBackupPRFAuthorizationSession, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private let controller: ASAuthorizationController
    private let context: PasskeyFirstOwnerPRFRequestContext
    private let anchor: () -> ASPresentationAnchor
    private var completion: ASFirstOwnerPRFExecutor.Completion?

    init(
        request: ASAuthorizationRequest, context: PasskeyFirstOwnerPRFRequestContext,
        presentationAnchor: @escaping () -> ASPresentationAnchor,
        completion: @escaping ASFirstOwnerPRFExecutor.Completion
    ) {
        controller = ASAuthorizationController(authorizationRequests: [request])
        self.context = context
        anchor = presentationAnchor
        self.completion = completion
        super.init()
        controller.delegate = self
        controller.presentationContextProvider = self
    }

    func start() {
        controller.performRequests()
    }

    func cancel() {
        completion = nil
        controller.cancel()
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        anchor()
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard controller === self.controller else { return }
        do {
            guard let credential = authorization.credential as?
                ASAuthorizationPlatformPublicKeyCredentialRegistration,
                let attestation = credential.rawAttestationObject else {
                throw PasskeyBackupPRFError.unexpectedCredential
            }
            let result = try PasskeyFirstOwnerPRFCeremonyResult.registration(
                context: context, credentialID: credential.credentialID,
                clientDataJSON: credential.rawClientDataJSON,
                attestationObject: attestation, prf: credential.prf
            )
            finish(.success(result))
        } catch let error as PasskeyBackupPRFError {
            finish(.failure(error))
        } catch {
            finish(.failure(PasskeyBackupFirstOwnerBootstrapError.invalidRegistration))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard controller === self.controller else { return }
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? PasskeyBackupPRFError.cancelled : .ceremonyFailed))
    }

    private func finish(_ result: Result<PasskeyFirstOwnerPRFCeremonyResult, Error>) {
        let callback = completion
        completion = nil
        callback?(result)
    }
}
