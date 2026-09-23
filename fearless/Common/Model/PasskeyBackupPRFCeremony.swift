import AuthenticationServices
import CryptoKit
import Foundation

enum PasskeyBackupPRFError: Error, Equatable {
    case invalidInput
    case unexpectedCredential
    case missingOutput
    case verificationUnavailable
    case verificationMismatch
    case invalidState
    case cancelled
    case ceremonyFailed
}

/// Local request binding, not proof of server verification or password-manager identity.
struct PasskeyBackupPRFContext: Equatable, CustomStringConvertible, CustomReflectable {
    enum Kind: String { case registration, assertion }
    let kind: Kind
    let ceremonyId: String
    let storageKey: String
    let challenge: Data
    let prfSalt: Data
    let expectedCredentialID: Data?

    private init(
        kind: Kind, ceremonyId: String, storageKey: String, challenge: Data,
        prfSalt: Data, expectedCredentialID: Data?
    ) throws {
        guard prfSalt.count == 32 else { throw PasskeyBackupPRFError.invalidInput }
        if let expectedCredentialID {
            guard (1 ... 384).contains(expectedCredentialID.count) else {
                throw PasskeyBackupPRFError.invalidInput
            }
        }
        self.kind = kind
        self.ceremonyId = try PasskeyBackupContract.validateCeremonyId(ceremonyId)
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        try PasskeyBackupContract.validateChallenge(challenge)
        self.challenge = challenge
        self.prfSalt = prfSalt
        self.expectedCredentialID = expectedCredentialID
    }

    static func registration(
        _ pending: PendingPasskeyBackupRegistration, prfSalt: Data
    ) throws -> Self {
        try Self(
            kind: .registration,
            ceremonyId: pending.registrationId,
            storageKey: pending.storageKey,
            challenge: pending.challenge,
            prfSalt: prfSalt,
            expectedCredentialID: nil
        )
    }

    static func assertion(
        _ pending: PendingPasskeyBackupAssertion, prfSalt: Data, credentialID: Data
    ) throws -> Self {
        guard let directedID = pending.credentialId,
              let boundID = try? PasskeyBackupContract.decodeBase64URL(directedID),
              boundID == credentialID else {
            throw PasskeyBackupPRFError.unexpectedCredential
        }
        return try Self(
            kind: .assertion,
            ceremonyId: pending.assertionId,
            storageKey: pending.storageKey,
            challenge: pending.challenge,
            prfSalt: prfSalt,
            expectedCredentialID: credentialID
        )
    }

    var description: String { "PasskeyBackupPRFContext(<redacted>)" }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

@available(iOS 18.0, *)
enum PasskeyBackupPRFRequestFactory {
    static func registration(
        _ pending: PendingPasskeyBackupRegistration, prfSalt: Data
    ) throws -> (ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest, PasskeyBackupPRFContext) {
        let context = try PasskeyBackupPRFContext.registration(pending, prfSalt: prfSalt)
        try PasskeyBackupContract.validateUserId(pending.userId)
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: PasskeyBackupContract.PASSKEY_RP_ID
        )
        let request = provider.createCredentialRegistrationRequest(
            challenge: pending.challenge, name: pending.userName, userID: pending.userId
        )
        request.displayName = pending.displayName
        request.userVerificationPreference = .required
        request.attestationPreference = .none
        request.prf = .inputValues(.saltInput1(prfSalt))
        return (request, context)
    }

    static func assertion(
        _ context: PasskeyBackupPRFContext
    ) throws -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
        guard context.kind == .assertion, let credentialID = context.expectedCredentialID else {
            throw PasskeyBackupPRFError.invalidInput
        }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: PasskeyBackupContract.PASSKEY_RP_ID
        )
        let request = provider.createCredentialAssertionRequest(challenge: context.challenge)
        request.allowedCredentials = [.init(credentialID: credentialID)]
        request.userVerificationPreference = .required
        request.prf = .perCredentialInputValues([credentialID: .saltInput1(context.prfSalt)])
        return request
    }
}

/// An unverified native result. Only its ordinary WebAuthn JSON may go to the challenge service.
/// PRF output has no Codable/JSON representation and is withheld until the enrollment gate verifies it.
final class PasskeyBackupPRFCeremonyResult: CustomStringConvertible, CustomReflectable {
    let context: PasskeyBackupPRFContext
    let credentialID: Data
    let credentialResponseJSON: String
    fileprivate let output: SymmetricKey?

    private init(
        context: PasskeyBackupPRFContext, credentialID: Data,
        credentialResponseJSON: String, output: SymmetricKey?
    ) throws {
        guard (1 ... 384).contains(credentialID.count),
              context.expectedCredentialID == nil || context.expectedCredentialID == credentialID,
              output == nil || output?.bitCount == 256 else {
            throw PasskeyBackupPRFError.unexpectedCredential
        }
        self.context = context
        self.credentialID = credentialID
        self.credentialResponseJSON = credentialResponseJSON
        self.output = output
    }

    @available(iOS 18.0, *)
    static func registration(
        context: PasskeyBackupPRFContext, credentialID: Data, clientDataJSON: Data,
        attestationObject: Data, prf: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?
    ) throws -> PasskeyBackupPRFCeremonyResult {
        guard context.kind == .registration, prf?.second == nil else {
            throw PasskeyBackupPRFError.invalidInput
        }
        let json = try PasskeyCredentialResponseSerializer.registrationJSON(
            credentialID: credentialID, clientDataJSON: clientDataJSON, attestationObject: attestationObject
        )
        return try Self(
            context: context,
            credentialID: credentialID,
            credentialResponseJSON: json,
            output: prf?.isSupported == true ? prf?.first : nil
        )
    }

    @available(iOS 18.0, *)
    // Mirrors the native assertion fields while keeping PRF separate from public JSON.
    // swiftlint:disable:next function_parameter_count
    static func assertion(
        context: PasskeyBackupPRFContext, credentialID: Data, clientDataJSON: Data,
        authenticatorData: Data, signature: Data, userHandle: Data?,
        prf: ASAuthorizationPublicKeyCredentialPRFAssertionOutput?
    ) throws -> PasskeyBackupPRFCeremonyResult {
        guard context.kind == .assertion,
              let allowedID = context.expectedCredentialID, allowedID == credentialID,
              let prf, prf.second == nil else {
            throw PasskeyBackupPRFError.missingOutput
        }
        let json = try PasskeyCredentialResponseSerializer.credentialDirectedAssertionJSON(
            credentialID: credentialID, allowedCredentialID: allowedID,
            clientDataJSON: clientDataJSON, authenticatorData: authenticatorData,
            signature: signature, userHandle: userHandle
        )
        return try Self(context: context, credentialID: credentialID, credentialResponseJSON: json, output: prf.first)
    }

    var requiresAssertion: Bool { context.kind == .registration && output == nil }
    var description: String { "PasskeyBackupPRFCeremonyResult(<redacted>)" }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// No PRF material: a future authenticated server adapter must verify this exact ceremony/credential/transcript.
struct PasskeyBackupPRFVerificationRequest {
    let context: PasskeyBackupPRFContext
    let credentialID: Data
    let credentialResponseJSON: String

    /// The only constructor takes a native ceremony result whose serializer excludes PRF output.
    init(result: PasskeyBackupPRFCeremonyResult) {
        context = result.context
        credentialID = result.credentialID
        credentialResponseJSON = result.credentialResponseJSON
    }

    var bindingSHA256: Data {
        var bytes = Data("FPBK-PRF-VERIFY-v1".utf8)
        for field in [Data(PasskeyBackupContract.PASSKEY_RP_ID.utf8), Data(context.kind.rawValue.utf8),
                      Data(context.ceremonyId.utf8), Data(context.storageKey.utf8), context.challenge, context.prfSalt,
                      credentialID, Data(credentialResponseJSON.utf8)] {
            var length = UInt32(field.count).bigEndian
            withUnsafeBytes(of: &length) { bytes.append(contentsOf: $0) }
            bytes.append(field)
        }
        return Data(SHA256.hash(data: bytes))
    }
}

/// Adapter contract only. Never construct this from a client-supplied "verified" field.
struct PasskeyBackupPRFVerificationReceipt {
    let requestBindingSHA256: Data
    let credentialID: Data
}

@MainActor
protocol PasskeyBackupPRFVerifier {
    func verify(_ request: PasskeyBackupPRFVerificationRequest) async throws -> PasskeyBackupPRFVerificationReceipt
}

/// Completes the exact one-use ceremony through the already authorized challenge service.
/// The only material sent is the sanitized public WebAuthn response; PRF stays local.
/// Enrollment still needs compensation/reconciliation after an uncertain server commit and
/// a verified backup round trip before a credential can become a recovery route.
@MainActor
final class ChallengeServicePasskeyBackupPRFVerifier: PasskeyBackupPRFVerifier {
    private let service: PasskeyBackupChallengeService

    init(service: PasskeyBackupChallengeService) { self.service = service }

    func verify(_ request: PasskeyBackupPRFVerificationRequest) async throws -> PasskeyBackupPRFVerificationReceipt {
        try Task.checkCancellation()
        let result: PasskeyBackupChallengeResult
        switch request.context.kind {
        case .registration:
            result = try await service.completeRegistration(
                registrationId: request.context.ceremonyId,
                credentialResponseJSON: request.credentialResponseJSON
            )
        case .assertion:
            guard let directedID = request.context.expectedCredentialID,
                  directedID == request.credentialID else {
                throw PasskeyBackupPRFError.unexpectedCredential
            }
            result = try await service.completeAssertion(
                assertionId: request.context.ceremonyId,
                credentialResponseJSON: request.credentialResponseJSON
            )
        }
        try Task.checkCancellation()
        guard result.storageKey == request.context.storageKey else {
            throw PasskeyBackupPRFError.verificationMismatch
        }
        return PasskeyBackupPRFVerificationReceipt(
            requestBindingSHA256: request.bindingSHA256,
            credentialID: request.credentialID
        )
    }
}

struct UnavailablePasskeyBackupPRFVerifier: PasskeyBackupPRFVerifier {
    func verify(_: PasskeyBackupPRFVerificationRequest) async throws -> PasskeyBackupPRFVerificationReceipt {
        throw PasskeyBackupPRFError.verificationUnavailable
    }
}

final class PasskeyBackupVerifiedLocalPRF: CustomStringConvertible, CustomReflectable {
    let credentialID: Data
    let prfSalt: Data
    let storageKey: String
    private let output: SymmetricKey

    fileprivate init(_ result: PasskeyBackupPRFCeremonyResult, output: SymmetricKey) {
        credentialID = result.credentialID
        prfSalt = result.context.prfSalt
        storageKey = result.context.storageKey
        self.output = output
    }

    func withOutput<T>(_ action: (Data) throws -> T) rethrows -> T {
        var bytes = output.withUnsafeBytes { Data($0) }
        defer { bytes.resetBytes(in: 0 ..< bytes.count) }
        return try action(bytes)
    }

    var description: String { "PasskeyBackupVerifiedLocalPRF(<redacted>)" }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// This is a ceremony precondition, not owner authorization, GPM qualification, or enrollment completion.
@MainActor
final class PasskeyBackupPRFEnrollmentGate {
    private enum State {
        case unverified, verifying, needsAssertion, awaitingAssertion(PasskeyBackupPRFContext)
        case ready(PasskeyBackupPRFCeremonyResult), consumed, failed
    }

    private let registration: PasskeyBackupPRFCeremonyResult
    private var state: State = .unverified

    init(registration: PasskeyBackupPRFCeremonyResult) throws {
        guard registration.context.kind == .registration else { throw PasskeyBackupPRFError.invalidInput }
        self.registration = registration
    }

    func verifyRegistration(
        using verifier: PasskeyBackupPRFVerifier? = nil
    ) async throws {
        guard case .unverified = state else { throw PasskeyBackupPRFError.invalidState }
        state = .verifying
        do {
            try await verify(registration, using: verifier ?? UnavailablePasskeyBackupPRFVerifier())
            state = registration.requiresAssertion ? .needsAssertion : .ready(registration)
        } catch {
            state = .failed
            throw error
        }
    }

    func assertionContext(_ pending: PendingPasskeyBackupAssertion) throws -> PasskeyBackupPRFContext {
        guard case .needsAssertion = state,
              pending.storageKey == registration.context.storageKey,
              pending.challenge != registration.context.challenge,
              pending.assertionId != registration.context.ceremonyId else {
            throw PasskeyBackupPRFError.invalidState
        }
        let context = try PasskeyBackupPRFContext.assertion(
            pending, prfSalt: registration.context.prfSalt, credentialID: registration.credentialID
        )
        state = .awaitingAssertion(context)
        return context
    }

    func verifyAssertion(
        _ result: PasskeyBackupPRFCeremonyResult,
        using verifier: PasskeyBackupPRFVerifier? = nil
    ) async throws {
        guard case let .awaitingAssertion(expected) = state, result.context == expected,
              result.credentialID == registration.credentialID, result.output != nil else {
            throw PasskeyBackupPRFError.invalidState
        }
        state = .verifying
        do {
            try await verify(result, using: verifier ?? UnavailablePasskeyBackupPRFVerifier())
            state = .ready(result)
        } catch {
            state = .failed
            throw error
        }
    }

    func takeVerifiedOutput() throws -> PasskeyBackupVerifiedLocalPRF {
        guard case let .ready(result) = state, let output = result.output else {
            throw PasskeyBackupPRFError.invalidState
        }
        state = .consumed
        return PasskeyBackupVerifiedLocalPRF(result, output: output)
    }

    private func verify(
        _ result: PasskeyBackupPRFCeremonyResult, using verifier: PasskeyBackupPRFVerifier
    ) async throws {
        try Task.checkCancellation()
        let request = PasskeyBackupPRFVerificationRequest(result: result)
        let receipt = try await verifier.verify(request)
        try Task.checkCancellation()
        guard receipt.requestBindingSHA256 == request.bindingSHA256,
              receipt.credentialID == result.credentialID else {
            throw PasskeyBackupPRFError.verificationMismatch
        }
    }
}
