import Foundation
import GoogleSignIn
import UIKit

enum GoogleDrivePasskeyBackupError: Error, Equatable {
    case unavailableConfiguration
    case consentRequired
    case authorizationFailed
    case accountChanged
    case invalidToken
    case malformedResponse
    case ambiguousBackup
    case immutableGenerationRequired
    case metadataTooLarge
    case httpStatus(Int)
}

/// A Google storage account is not a Fearless wallet owner or a recovery credential.
struct GoogleDriveBackupAccount: Equatable {
    let subject: String
    let email: String

    init(subject: String, email: String) throws {
        guard subject.range(of: #"\A[A-Za-z0-9_-]{1,255}\z"#, options: .regularExpression) != nil else {
            throw GoogleDrivePasskeyBackupError.authorizationFailed
        }
        self.subject = subject
        self.email = try PasskeyBackupContract.validateAccountName(email)
    }
}

/// Deliberately not Codable. Tokens must never enter backup metadata, owner grants or logs.
struct GoogleDriveBackupAuthorization: CustomStringConvertible, CustomDebugStringConvertible {
    let account: GoogleDriveBackupAccount
    let clientID: String
    let scopes: Set<String>
    let accessToken: String
    let expiresAt: Date?

    var description: String { "GoogleDriveBackupAuthorization(<redacted>)" }
    var debugDescription: String { description }

    func validate(now: Date) throws {
        guard scopes.contains(GoogleDrivePasskeyBackupCloudStorage.appDataScope) else {
            throw GoogleDrivePasskeyBackupError.consentRequired
        }
        guard let expiresAt, expiresAt.timeIntervalSince(now) > 30,
              accessToken.utf8.count <= 8192,
              accessToken.range(of: #"\A[A-Za-z0-9\-._~+/]+=*\z"#, options: .regularExpression) != nil else {
            throw GoogleDrivePasskeyBackupError.invalidToken
        }
    }
}

protocol GoogleDriveBackupAccessTokenProvider {
    func authorization() async throws -> GoogleDriveBackupAuthorization
}

@MainActor
protocol GoogleDriveBackupOAuthSession {
    var clientID: String { get }
    func currentAuthorization() throws -> GoogleDriveBackupAuthorization?
    func requestConsent(presenting: UIViewController) async throws -> GoogleDriveBackupAuthorization
    func refreshAuthorization() async throws -> GoogleDriveBackupAuthorization
}

@MainActor
final class GoogleDrivePasskeyBackupTokenProvider: GoogleDriveBackupAccessTokenProvider {
    let account: GoogleDriveBackupAccount
    private let session: GoogleDriveBackupOAuthSession
    private let now: () -> Date

    init(
        account: GoogleDriveBackupAccount,
        session: GoogleDriveBackupOAuthSession,
        now: @escaping () -> Date = Date.init
    ) {
        self.account = account
        self.session = session
        self.now = now
    }

    /// Invoke only from an explicit account/consent user action, never during storage I/O.
    static func requestConsent(
        presenting: UIViewController,
        session: GoogleDriveBackupOAuthSession,
        now: @escaping () -> Date = Date.init
    ) async throws -> GoogleDrivePasskeyBackupTokenProvider {
        try Task.checkCancellation()
        let authorization = try await session.requestConsent(presenting: presenting)
        try Task.checkCancellation()
        guard authorization.clientID == session.clientID else {
            throw GoogleDrivePasskeyBackupError.unavailableConfiguration
        }
        try authorization.validate(now: now())
        let provider = GoogleDrivePasskeyBackupTokenProvider(account: authorization.account, session: session, now: now)
        _ = try provider.requireSelectedAccount(session.currentAuthorization())
        return provider
    }

    func authorization() async throws -> GoogleDriveBackupAuthorization {
        try Task.checkCancellation()
        _ = try requireSelectedAccount(session.currentAuthorization())
        let refreshed = try await session.refreshAuthorization()
        try Task.checkCancellation()
        _ = try requireSelectedAccount(session.currentAuthorization())
        let authorized = try requireSelectedAccount(refreshed)
        try authorized.validate(now: now())
        return authorized
    }

    private func requireSelectedAccount(_ authorization: GoogleDriveBackupAuthorization?) throws
        -> GoogleDriveBackupAuthorization {
        guard let authorization else { throw GoogleDrivePasskeyBackupError.consentRequired }
        guard authorization.account.subject == account.subject
        else { throw GoogleDrivePasskeyBackupError.accountChanged }
        guard authorization.clientID == session.clientID
        else { throw GoogleDrivePasskeyBackupError.unavailableConfiguration }
        guard authorization.scopes.contains(GoogleDrivePasskeyBackupCloudStorage.appDataScope) else {
            throw GoogleDrivePasskeyBackupError.consentRequired
        }
        return authorization
    }
}

struct GoogleDriveBackupOAuthConfiguration {
    let clientID: String
    let callbackScheme: String

    init(info: [String: Any]) throws {
        guard let clientID = info["GIDClientID"] as? String,
              clientID.range(
                  of: #"\A[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com\z"#,
                  options: .regularExpression
              ) != nil else {
            throw GoogleDrivePasskeyBackupError.unavailableConfiguration
        }
        let callbackScheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        let types = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        guard schemes.filter({ $0 == callbackScheme }).count == 1 else {
            throw GoogleDrivePasskeyBackupError.unavailableConfiguration
        }
        self.clientID = clientID
        self.callbackScheme = callbackScheme
    }
}

@MainActor
final class NativeGoogleDriveBackupOAuthSession: GoogleDriveBackupOAuthSession {
    let clientID: String
    private let signIn: GIDSignIn

    init(
        info: [String: Any] = Bundle.main.infoDictionary ?? [:],
        signInFactory: () -> GIDSignIn = { .sharedInstance }
    ) throws {
        let configuration = try GoogleDriveBackupOAuthConfiguration(info: info)
        // Initializing Google's singleton may migrate saved sign-in state. Do so only after configuration passes.
        let signIn = signInFactory()
        guard signIn.configuration?.clientID == configuration.clientID else {
            throw GoogleDrivePasskeyBackupError.unavailableConfiguration
        }
        clientID = configuration.clientID
        self.signIn = signIn
    }

    func currentAuthorization() throws -> GoogleDriveBackupAuthorization? {
        try signIn.currentUser.map(Self.authorization)
    }

    func requestConsent(presenting: UIViewController) async throws -> GoogleDriveBackupAuthorization {
        // Always use Google's native account selection/consent UI for this explicit action.
        // Do not silently adopt an account restored by the unrelated legacy backup flow.
        do {
            let result = try await signIn.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: [GoogleDrivePasskeyBackupCloudStorage.appDataScope]
            )
            return try Self.authorization(result.user)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw GoogleDrivePasskeyBackupError.authorizationFailed
        }
    }

    func refreshAuthorization() async throws -> GoogleDriveBackupAuthorization {
        guard let user = signIn.currentUser else { throw GoogleDrivePasskeyBackupError.consentRequired }
        do {
            return try Self.authorization(await user.refreshTokensIfNeeded())
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw GoogleDrivePasskeyBackupError.authorizationFailed
        }
    }

    private static func authorization(_ user: GIDGoogleUser) throws -> GoogleDriveBackupAuthorization {
        guard let subject = user.userID, let email = user.profile?.email else {
            throw GoogleDrivePasskeyBackupError.authorizationFailed
        }
        return GoogleDriveBackupAuthorization(
            account: try GoogleDriveBackupAccount(subject: subject, email: email),
            clientID: user.configuration.clientID,
            scopes: Set(user.grantedScopes ?? []),
            accessToken: user.accessToken.tokenString,
            expiresAt: user.accessToken.expirationDate
        )
    }
}

/// Google's SDK validates the pending OAuth state; this handler only admits the configured scheme.
final class GoogleDriveBackupURLHandler: URLHandlingServiceProtocol {
    static let shared = GoogleDriveBackupURLHandler()
    private let configuration: () -> GoogleDriveBackupOAuthConfiguration?
    private let handleURL: (URL) -> Bool

    init(
        configuration: @escaping () -> GoogleDriveBackupOAuthConfiguration? = {
            try? GoogleDriveBackupOAuthConfiguration(info: Bundle.main.infoDictionary ?? [:])
        },
        handleURL: @escaping (URL) -> Bool = { GIDSignIn.sharedInstance.handle($0) }
    ) {
        self.configuration = configuration
        self.handleURL = handleURL
    }

    func handle(url: URL) -> Bool {
        guard let configuration = configuration(), url.scheme == configuration.callbackScheme else { return false }
        return handleURL(url)
    }
}
