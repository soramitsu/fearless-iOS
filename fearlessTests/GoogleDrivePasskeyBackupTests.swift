import UIKit
import XCTest
@testable import fearless

@MainActor
final class GoogleDrivePasskeyBackupTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_800_000_000)
    private let clientID = "123456789-syntheticNative.apps.googleusercontent.com"

    func testCreateUsesAndroidCompatibleMetadataAndUnchangedEncryptedBytes() async throws {
        let record = try record()
        let (storage, transport, provider) = try fixture(responses: [list([]), fileResponse(record)])
        try await storage.savePasskeyBackup(record)
        XCTAssertEqual(transport.requests.map(\.method), ["GET", "POST"])
        XCTAssertEqual(provider.calls, 2)
        let request = transport.requests[1]
        XCTAssertEqual(request.url.host, "www.googleapis.com")
        XCTAssertEqual(request.url.path, "/upload/drive/v3/files")
        let body = try XCTUnwrap(request.body)
        XCTAssertNotNil(body.range(of: record.encryptedPayload))
        let parts = try multipart(request)
        XCTAssertEqual(parts["parents"] as? [String], ["appDataFolder"])
        XCTAssertEqual(parts["appProperties"] as? [String: String], properties(record))
        XCTAssertEqual(parts["name"] as? String, name(record))
        XCTAssertEqual(query(transport.requests[0].url)["spaces"], "appDataFolder")
        XCTAssertTrue(query(transport.requests[0].url)["fields"]?.contains("nextPageToken") == true)
    }

    func testExistingLegacyBackupCannotBeOverwrittenBeforeImmutableGenerationMigration() async throws {
        let record = try record()
        let (storage, transport, _) = try fixture(responses: [
            list([file(record)]), list([file(record)]), .init(statusCode: 200, body: record.encryptedPayload)
        ])
        await assertError(.immutableGenerationRequired) { try await storage.savePasskeyBackup(record) }
        let loaded = try await storage.loadPasskeyBackup(storageKey: record.storageKey)
        XCTAssertEqual(loaded, record)
        XCTAssertEqual(transport.requests.map(\.method), ["GET", "GET", "GET"])
    }

    func testLoadsAndroidMetadataAndAuthenticatesOriginalAADAfterAccountEmailRename() async throws {
        let record = try record(email: "original@example.com")
        let (
            storage,
            _,
            _
        ) = try fixture(responses: [list([file(record)]), .init(statusCode: 200, body: record.encryptedPayload)])
        let downloaded = try await storage.loadPasskeyBackup(storageKey: record.storageKey)
        let loaded = try XCTUnwrap(downloaded)
        XCTAssertEqual(loaded, record)
        let plaintext = try AESGCMPasskeyBackupEnvelopeCryptography().decrypt(
            loaded.encryptedPayload, metadata: loaded.envelopeMetadata(), key: Data(repeating: 0xA5, count: 32)
        )
        XCTAssertEqual(plaintext, Data("synthetic wallet payload".utf8))
    }

    func testMissingFileDoesNotCreateDownloadOrDeleteAnything() async throws {
        let (storage, transport, _) = try fixture(responses: [list([]), list([])])
        let loaded = try await storage.loadPasskeyBackup(storageKey: "storage-1234")
        XCTAssertNil(loaded)
        try await storage.deletePasskeyBackup(storageKey: "storage-1234")
        XCTAssertEqual(transport.requests.map(\.method), ["GET", "GET"])
    }

    func testDeletedDuringDownloadReturnsMissingAndDelete404IsIdempotent() async throws {
        let record = try record()
        let (storage, transport, _) = try fixture(responses: [
            list([file(record)]), .init(statusCode: 404), list([file(record)]), .init(statusCode: 404)
        ])
        let loaded = try await storage.loadPasskeyBackup(storageKey: record.storageKey)
        XCTAssertNil(loaded)
        try await storage.deletePasskeyBackup(storageKey: record.storageKey)
        XCTAssertEqual(transport.requests.map(\.method), ["GET", "GET", "GET", "DELETE"])
    }

    func testDuplicateOrIncompleteLookupNeverUploadsOrDeletes() async throws {
        let record = try record()
        for response in try [
            list([file(record), file(record)]),
            json(["files": [], "nextPageToken": "another-page"]),
            json(["files": [file(record)], "incompleteSearch": true])
        ] {
            let (storage, transport, _) = try fixture(responses: [response])
            await assertError(.ambiguousBackup) { try await storage.savePasskeyBackup(record) }
            XCTAssertEqual(transport.requests.map(\.method), ["GET"])
        }
    }

    func testMalformedFileIdentityAndMetadataNeverDownload() async throws {
        let record = try record()
        var variants: [[String: Any]] = []
        for (key, value) in [("id", "../other?alt=media"), ("id", ""), ("name", "other-file.bin")] {
            var changed = file(record)
            changed[key] = value
            variants.append(changed)
        }
        for (key, value) in [("storageKey", "other-storage"), ("schemaVersion", "2"), ("schemaVersion", "01"),
                             ("createdAtMillis", "001"), ("createdAtMillis", "-1"), ("walletId", "bad"),
                             ("accountName", "bad")] {
            var changed = file(record)
            var metadata = properties(record)
            metadata[key] = value
            changed["appProperties"] = metadata
            variants.append(changed)
        }
        for variant in variants {
            let (storage, transport, _) = try fixture(responses: [list([variant])])
            do {
                _ = try await storage.loadPasskeyBackup(storageKey: record.storageKey)
                XCTFail("Malformed metadata was accepted")
            } catch { XCTAssertEqual(transport.requests.count, 1) }
        }
    }

    func testRejectsMalformedListAndOversizeInjectedResponse() async throws {
        let (malformed, transport, _) = try fixture(responses: [json(["files": "not-an-array"])])
        await assertError(.malformedResponse) { _ = try await malformed.loadPasskeyBackup(storageKey: "storage-1234") }
        XCTAssertEqual(transport.requests.count, 1)
        let (oversize, _, _) = try fixture(responses: [
            .init(
                statusCode: 200,
                body: Data(repeating: 0, count: PasskeyBackupHTTPTransportPolicy.maximumResponseBytes + 1)
            )
        ])
        do {
            _ = try await oversize.loadPasskeyBackup(storageKey: "storage-1234")
            XCTFail("Oversize response was accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupError, .challengeServiceResponseTooLarge) }
    }

    func testPreflightsDrivePropertyLimitBeforeTokenOrNetworkAccess() async throws {
        let record = try record(email: String(repeating: "a", count: 120) + "@example.com")
        let (storage, transport, provider) = try fixture(responses: [])
        await assertError(.metadataTooLarge) { try await storage.savePasskeyBackup(record) }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(provider.calls, 0)
    }

    func testInvalidStorageKeyNeverRequestsToken() async throws {
        let (storage, transport, provider) = try fixture(responses: [])
        do {
            _ = try await storage.loadPasskeyBackup(storageKey: "x' or true")
            XCTFail("Invalid key was accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupError, .invalidStorageKey) }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(provider.calls, 0)
    }

    func testAccountSwitchBetweenListAndUploadPreventsUpload() async throws {
        let record = try record()
        let (storage, transport, provider) = try fixture(responses: [list([])])
        provider.values.append(try authorization(subject: "other-subject"))
        await assertError(.accountChanged) { try await storage.savePasskeyBackup(record) }
        XCTAssertEqual(transport.requests.map(\.method), ["GET"])
    }

    func testMissingScopeExpiredTokenAndHeaderInjectionNeverReachNetwork() async throws {
        for value in try [
            authorization(scopes: []), authorization(expires: time), authorization(token: "bad\r\nHeader: token")
        ] {
            let (storage, transport, provider) = try fixture(responses: [])
            provider.values = [value]
            do {
                _ = try await storage.loadPasskeyBackup(storageKey: "storage-1234")
                XCTFail("Invalid authorization was accepted")
            } catch { XCTAssertTrue(transport.requests.isEmpty) }
        }
    }

    func testRejectedUploadIsNeverRetried() async throws {
        let record = try record()
        let (storage, transport, _) = try fixture(responses: [list([]), .init(statusCode: 401)])
        await assertError(.httpStatus(401)) { try await storage.savePasskeyBackup(record) }
        XCTAssertEqual(transport.requests.map(\.method), ["GET", "POST"])
    }

    func testCancellationDuringUploadDoesNotRetryOrReportSuccess() async throws {
        let record = try record()
        let (storage, transport, _) = try fixture(responses: [list([])])
        transport.failAt = 2
        do {
            try await storage.savePasskeyBackup(record)
            XCTFail("Cancelled upload reported success")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(transport.requests.map(\.method), ["GET", "POST"])
    }

    func testMismatchedUploadAcknowledgmentDoesNotReportSuccess() async throws {
        let record = try record()
        var changed = file(record)
        changed["appProperties"] = ["storageKey": "different-storage"]
        let (storage, transport, _) = try fixture(responses: [list([]), json(changed)])
        await assertError(.malformedResponse) { try await storage.savePasskeyBackup(record) }
        XCTAssertEqual(transport.requests.map(\.method), ["GET", "POST"])
    }

    func testNativeConsentRequestsAccountAndChecksScope() async throws {
        let session = DriveOAuthFixture(value: try authorization())
        var confirmedAccount: GoogleDriveBackupAccount?
        let provider = try await GoogleDrivePasskeyBackupTokenProvider.requestConsent(
            presenting: UIViewController(),
            session: session,
            confirmSelectedAccount: { account in confirmedAccount = account; return true },
            now: { self.time }
        )
        XCTAssertEqual(session.consentCalls, 1)
        XCTAssertEqual(confirmedAccount, try account())
        XCTAssertEqual(provider.account, try account())
        let token = try await provider.authorization()
        XCTAssertEqual(token.accessToken, "synthetic-token")
        XCTAssertEqual(session.refreshCalls, 1)
        XCTAssertEqual(String(reflecting: token), "GoogleDriveBackupAuthorization(<redacted>)")
    }

    func testDeniedConsentCannotCreateAProvider() async throws {
        let session = DriveOAuthFixture(value: try authorization(scopes: []))
        await assertError(.consentRequired) {
            _ = try await GoogleDrivePasskeyBackupTokenProvider.requestConsent(
                presenting: UIViewController(),
                session: session,
                confirmSelectedAccount: { _ in XCTFail("Unconsented account reached confirmation"); return true },
                now: { self.time }
            )
        }
        XCTAssertEqual(session.refreshCalls, 0)
    }

    func testDeclinedAccountConfirmationCannotCreateAProvider() async throws {
        let session = DriveOAuthFixture(value: try authorization())
        await assertError(.accountSelectionDeclined) {
            _ = try await GoogleDrivePasskeyBackupTokenProvider.requestConsent(
                presenting: UIViewController(), session: session,
                confirmSelectedAccount: { account in
                    XCTAssertEqual(account, try self.account())
                    return false
                }, now: { self.time }
            )
        }
        XCTAssertEqual(session.consentCalls, 1)
        XCTAssertEqual(session.refreshCalls, 0)
    }

    func testAccountSwitchDuringConfirmationCannotCreateAProvider() async throws {
        let session = DriveOAuthFixture(value: try authorization())
        await assertError(.accountChanged) {
            _ = try await GoogleDrivePasskeyBackupTokenProvider.requestConsent(
                presenting: UIViewController(), session: session,
                confirmSelectedAccount: { account in
                    XCTAssertEqual(account.subject, "google-subject")
                    session.value = try self.authorization(subject: "other-subject")
                    return true
                }, now: { self.time }
            )
        }
        XCTAssertEqual(session.refreshCalls, 0)
    }

    func testProviderRejectsMissingOrChangedAccountBeforeRefresh() async throws {
        for value in [nil, try authorization(subject: "other-subject")] {
            let session = DriveOAuthFixture(value: value, clientID: clientID)
            let provider = try GoogleDrivePasskeyBackupTokenProvider(
                account: account(),
                session: session,
                now: { self.time }
            )
            do {
                _ = try await provider.authorization()
                XCTFail("Unselected account was accepted")
            } catch { XCTAssertEqual(session.refreshCalls, 0) }
        }
    }

    func testAccountChangeDuringRefreshInvalidatesReturnedOldToken() async throws {
        let session = DriveOAuthFixture(value: try authorization())
        let provider = try GoogleDrivePasskeyBackupTokenProvider(
            account: account(),
            session: session,
            now: { self.time }
        )
        let old = try authorization()
        session.refresh = { session.value = try self.authorization(subject: "other-subject"); return old }
        await assertError(.accountChanged) { _ = try await provider.authorization() }
    }

    func testProviderRejectsWrongClientAndExpiredRefreshedToken() async throws {
        let session = DriveOAuthFixture(value: try authorization())
        let provider = try GoogleDrivePasskeyBackupTokenProvider(
            account: account(),
            session: session,
            now: { self.time }
        )
        session.refresh = { try self.authorization(expires: self.time) }
        await assertError(.invalidToken) { _ = try await provider.authorization() }
        session.clientID = "other-client"
        await assertError(.unavailableConfiguration) { _ = try await provider.authorization() }
    }

    func testOAuthConfigurationRequiresExactSingleRegisteredCallbackScheme() throws {
        let info = configurationInfo()
        let config = try GoogleDriveBackupOAuthConfiguration(info: info)
        XCTAssertEqual(config.clientID, clientID)
        XCTAssertEqual(config.callbackScheme, "com.googleusercontent.apps.123456789-syntheticNative")
        for bad in [[:], ["GIDClientID": clientID], ["GIDClientID": "not-a-client"],
                    [
                        "GIDClientID": clientID,
                        "CFBundleURLTypes": [["CFBundleURLSchemes": [config.callbackScheme, config.callbackScheme]]]
                    ]] as [[String: Any]] {
            XCTAssertThrowsError(try GoogleDriveBackupOAuthConfiguration(info: bad))
        }
        XCTAssertThrowsError(try GoogleDriveBackupAccount(subject: "bad\nsubject", email: "alice@example.com"))
    }

    func testURLHandlerOnlyForwardsConfiguredOAuthSchemeAndPreservesSDKResult() throws {
        let config = try GoogleDriveBackupOAuthConfiguration(info: configurationInfo())
        var calls = 0
        let handler = GoogleDriveBackupURLHandler(
            configuration: { config },
            handleURL: { _ in calls += 1; return false }
        )
        XCTAssertFalse(handler.handle(url: try XCTUnwrap(URL(string: "fearless://callback"))))
        XCTAssertFalse(
            handler
                .handle(url: try XCTUnwrap(URL(string: "\(config.callbackScheme):/oauthredirect?state=synthetic")))
        )
        XCTAssertEqual(calls, 1)
        let unavailable = GoogleDriveBackupURLHandler(
            configuration: { nil },
            handleURL: { _ in XCTFail("Unconfigured OAuth invoked"); return true }
        )
        XCTAssertFalse(unavailable.handle(url: try XCTUnwrap(URL(string: "\(config.callbackScheme):/oauthredirect"))))
    }

    func testDisabledCompositionDoesNotAccessGoogleOrChallengeService() throws {
        let provider = DriveTokenFixture(values: [])
        let service = try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: DriveHTTPFixture(responses: [])
        )
        XCTAssertThrowsError(try PasskeyBackupComposition.makeGoogleDriveClient(
            account: account(), tokenProvider: provider, challengeService: service,
            presentationAnchorProvider: { UIWindow() }
        )) { XCTAssertEqual($0 as? PasskeyBackupError, .passkeyBackupDisabled) }
        XCTAssertEqual(provider.calls, 0)
        XCTAssertFalse(PasskeyBackupReleaseConfig.isPasskeyBackupEnabled)
    }

    func testMissingNativeConfigurationDoesNotInitializeGoogleSDK() {
        var sdkInitializations = 0
        XCTAssertThrowsError(try NativeGoogleDriveBackupOAuthSession(info: [:], signInFactory: {
            sdkInitializations += 1
            return .sharedInstance
        })) { XCTAssertEqual($0 as? GoogleDrivePasskeyBackupError, .unavailableConfiguration) }
        XCTAssertEqual(sdkInitializations, 0)
    }

    func testCancelledConsentAndRefreshDoNotInvokeNativeSession() async throws {
        let session = DriveOAuthFixture(value: try authorization())
        let consent = Task { @MainActor in
            try await GoogleDrivePasskeyBackupTokenProvider.requestConsent(
                presenting: UIViewController(), session: session,
                confirmSelectedAccount: { _ in XCTFail("Cancelled consent reached confirmation"); return true },
                now: { self.time }
            )
        }
        consent.cancel()
        do { _ = try await consent.value; XCTFail("Cancelled consent continued") }
        catch { XCTAssertTrue(error is CancellationError) }
        let provider = try GoogleDrivePasskeyBackupTokenProvider(account: account(), session: session)
        let refresh = Task { @MainActor in try await provider.authorization() }
        refresh.cancel()
        do { _ = try await refresh.value; XCTFail("Cancelled refresh continued") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(session.consentCalls, 0)
        XCTAssertEqual(session.refreshCalls, 0)
    }

    func testCancelledStorageOperationDoesNotFetchTokenOrSendRequest() async throws {
        let (storage, transport, provider) = try fixture(responses: [])
        let task = Task { @MainActor in try await storage.loadPasskeyBackup(storageKey: "storage-1234") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled storage continued") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(provider.calls, 0)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    private func account(subject: String = "google-subject") throws -> GoogleDriveBackupAccount {
        try GoogleDriveBackupAccount(subject: subject, email: "alice@example.com")
    }

    private func authorization(
        subject: String = "google-subject", scopes: Set<String> = [GoogleDrivePasskeyBackupCloudStorage.appDataScope],
        token: String = "synthetic-token", expires: Date? = nil
    ) throws -> GoogleDriveBackupAuthorization {
        GoogleDriveBackupAuthorization(
            account: try account(subject: subject),
            clientID: clientID,
            scopes: scopes,
            accessToken: token,
            expiresAt: expires ?? time.addingTimeInterval(3600)
        )
    }

    private func record(email: String = "alice@example.com") throws -> PasskeyBackupEncryptedRecord {
        let metadata = try PasskeyBackupEnvelopeMetadata(
            storageKey: "storage-1234",
            walletId: "wallet-1234",
            accountName: email,
            createdAtMillis: 1_800_000_000_000
        )
        let encrypted = try AESGCMPasskeyBackupEnvelopeCryptography()
            .encrypt(Data("synthetic wallet payload".utf8), metadata: metadata, key: Data(repeating: 0xA5, count: 32))
        return try PasskeyBackupEncryptedRecord(
            storageKey: metadata.storageKey,
            walletId: metadata.walletId,
            accountName: metadata.accountName,
            createdAtMillis: metadata.createdAtMillis,
            encryptedPayload: encrypted
        )
    }

    private func properties(_ record: PasskeyBackupEncryptedRecord) -> [String: String] {
        ["storageKey": record.storageKey, "walletId": record.walletId, "accountName": record.accountName,
         "createdAtMillis": String(record.createdAtMillis), "schemaVersion": String(record.schemaVersion)]
    }

    private func name(_ record: PasskeyBackupEncryptedRecord)
        -> String { "fearless-passkey-backup-\(record.storageKey).bin" }
    private func file(_ record: PasskeyBackupEncryptedRecord) -> [String: Any] {
        ["id": "drive-id_123", "name": name(record), "appProperties": properties(record)]
    }

    private func json(_ object: [String: Any]) throws -> PasskeyBackupHTTPResponse {
        try PasskeyBackupHTTPResponse(statusCode: 200, body: JSONSerialization.data(withJSONObject: object))
    }

    private func list(_ files: [[String: Any]]) throws -> PasskeyBackupHTTPResponse { try json(["files": files]) }
    private func fileResponse(_ record: PasskeyBackupEncryptedRecord) throws
        -> PasskeyBackupHTTPResponse { try json(file(record)) }
    private func fixture(responses: [PasskeyBackupHTTPResponse]) throws
        -> (GoogleDrivePasskeyBackupCloudStorage, DriveHTTPFixture, DriveTokenFixture) {
        let transport = DriveHTTPFixture(responses: responses)
        let provider = try DriveTokenFixture(values: [authorization()])
        return (
            try GoogleDrivePasskeyBackupCloudStorage(
                account: account(),
                tokenProvider: provider,
                transport: transport,
                now: { self.time }
            ),
            transport,
            provider
        )
    }

    private func query(_ url: URL) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
                .map { ($0.name, $0.value ?? "") }
        )
    }

    private func multipart(_ request: PasskeyBackupHTTPRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.body)
        let start = try XCTUnwrap(body.range(of: Data("\r\n\r\n".utf8)))
        let end = try XCTUnwrap(body.range(of: Data("\r\n--".utf8), in: start.upperBound ..< body.endIndex))
        return try XCTUnwrap(
            JSONSerialization
                .jsonObject(with: body[start.upperBound ..< end.lowerBound]) as? [String: Any]
        )
    }

    private func configurationInfo() -> [String: Any] {
        [
            "GIDClientID": clientID,
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["com.googleusercontent.apps.123456789-syntheticNative"]]]
        ]
    }

    private func assertError(_ expected: GoogleDrivePasskeyBackupError, operation: () async throws -> Void) async {
        do { try await operation(); XCTFail("Operation unexpectedly succeeded") } catch {
            XCTAssertEqual(error as? GoogleDrivePasskeyBackupError, expected)
        }
    }
}

private final class DriveHTTPFixture: PasskeyBackupHTTPTransport {
    var responses: [PasskeyBackupHTTPResponse]
    var requests: [PasskeyBackupHTTPRequest] = []
    var failAt: Int?
    init(responses: [PasskeyBackupHTTPResponse]) { self.responses = responses }
    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        requests.append(request)
        if failAt == requests.count { throw CancellationError() }
        guard !responses.isEmpty else { throw GoogleDrivePasskeyBackupError.malformedResponse }
        return responses.removeFirst()
    }
}

private final class DriveTokenFixture: GoogleDriveBackupAccessTokenProvider {
    var values: [GoogleDriveBackupAuthorization]
    var calls = 0
    init(values: [GoogleDriveBackupAuthorization]) { self.values = values }
    func authorization() async throws -> GoogleDriveBackupAuthorization {
        calls += 1
        guard !values.isEmpty else { throw GoogleDrivePasskeyBackupError.authorizationFailed }
        return values.count == 1 ? values[0] : values.removeFirst()
    }
}

@MainActor
private final class DriveOAuthFixture: GoogleDriveBackupOAuthSession {
    var value: GoogleDriveBackupAuthorization?
    var clientID: String
    var consentCalls = 0
    var refreshCalls = 0
    var refresh: (() throws -> GoogleDriveBackupAuthorization)?
    init(value: GoogleDriveBackupAuthorization?, clientID: String? = nil) {
        self.value = value
        self.clientID = clientID ?? value?.clientID ?? ""
    }

    func currentAuthorization() throws -> GoogleDriveBackupAuthorization? { value }
    func requestConsent(presenting _: UIViewController) async throws -> GoogleDriveBackupAuthorization {
        consentCalls += 1
        return try XCTUnwrap(value)
    }

    func refreshAuthorization() async throws -> GoogleDriveBackupAuthorization {
        refreshCalls += 1
        return try refresh?() ?? XCTUnwrap(value)
    }
}
