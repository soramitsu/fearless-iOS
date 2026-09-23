import UIKit
import XCTest
@testable import fearless

@MainActor
final class GoogleDrivePasskeyGenerationStorageTests: XCTestCase {
    private let subject = "google-subject-123"
    private let fileID = "preallocated-drive-id"

    func testAllocatesExactlyOneAppDataIDWithScopedAuthorization() async throws {
        let fixture = try fixture()
        fixture.transport.responses = [.success(.init(statusCode: 200, body: Data(
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["preallocated-drive-id"]}"#.utf8
        )))]
        let identifier = try await fixture.store.allocateFileID()
        XCTAssertEqual(identifier, fileID)
        let request = try XCTUnwrap(fixture.transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url.path, "/drive/v3/files/generateIds")
        XCTAssertEqual(Set(URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!), Set([
            URLQueryItem(name: "count", value: "1"), URLQueryItem(name: "space", value: "appDataFolder"),
            URLQueryItem(name: "type", value: "files")
        ]))
        XCTAssertEqual(request.headers["Authorization"], "Bearer fixture-token")
        XCTAssertEqual(request.headers["Cache-Control"], "no-store")
        XCTAssertNil(request.body)
        XCTAssertEqual(fixture.oauth.refreshes, 1)
    }

    func testAllocationRejectsDuplicateEscapedKeysAmbiguousIDsAndHostileJSON() async throws {
        let responses = [
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["id","other"]}"#,
            #"{"kind":"drive#generatedIds","space":"drive","ids":["id"]}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["../id"]}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["id"],"ids":["other"]}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["id"],"\u0069ds":["id"]}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["id"]}{}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":[5]}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["id"],}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":[[[]]]}"#,
            #"{"kind":"drive#generatedIds","space":"appDataFolder","ids":["\uD800"]}"#
        ]
        for response in responses {
            let fixture = try fixture()
            fixture.transport.responses = [.success(.init(statusCode: 200, body: Data(response.utf8)))]
            await assertFailure { _ = try await fixture.store.allocateFileID() }
            XCTAssertEqual(fixture.transport.requests.count, 1)
        }
    }

    func testImmutableCreateUsesPreallocatedIDAndExactCanonicalBundleOnlyOnce() async throws {
        let fixture = try fixture()
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
        fixture.transport.responses = [.success(.init(statusCode: 201, body: try metadata(candidate)))]
        let outcome = try await fixture.store.createCandidate(candidate)
        XCTAssertEqual(outcome, .acknowledged)
        XCTAssertEqual(fixture.transport.requests.count, 1)
        let request = try XCTUnwrap(fixture.transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.path, "/upload/drive/v3/files")
        XCTAssertEqual(URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems?.first {
            $0.name == "uploadType"
        }?.value, "multipart")
        let body = try XCTUnwrap(request.body)
        XCTAssertNotNil(body.range(of: candidate.bytes))
        let header = try XCTUnwrap(String(data: body.prefix(while: { $0 != 0 }), encoding: .utf8))
        XCTAssertTrue(header.contains("\"id\":\"\(fileID)\""))
        XCTAssertTrue(header.contains("\"parents\":[\"appDataFolder\"]"))
        XCTAssertTrue(header.contains("\"format\":\"FPBKGEN1\""))
        XCTAssertFalse(header.contains("fixture-token"))
        XCTAssertEqual(candidate.size, 785)
        XCTAssertEqual(candidate.sha256, "1c92b544dc25c687c202317d0e5747b5690a1056cf72e61d1dfab84c07c057a4")
        XCTAssertEqual(String(reflecting: candidate), "DriveGenerationCandidate(<redacted>)")
        XCTAssertFalse(PasskeyBackupReleaseConfig.isPasskeyBackupEnabled)
    }

    func testLostResponseConflictRedirectAndMalformedAcknowledgementRequireReconciliationWithoutRetry() async throws {
        for result: Result<PasskeyBackupHTTPResponse, Error> in [
            .failure(URLError(.networkConnectionLost)), .success(.init(statusCode: 409)),
            .success(.init(statusCode: 302)), .success(.init(statusCode: 401)),
            .success(.init(statusCode: 500)), .success(.init(statusCode: 201, body: Data("{}".utf8)))
        ] {
            let fixture = try fixture()
            let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
            fixture.transport.responses = [result]
            let outcome = try await fixture.store.createCandidate(candidate)
            XCTAssertEqual(outcome, .reconcileRequired)
            XCTAssertEqual(fixture.transport.requests.map(\.method), ["POST"])
            XCTAssertEqual(fixture.oauth.refreshes, 1)
        }
    }

    func testCancelledUploadThrowsAndNeverRetriesOrDeletes() async throws {
        let fixture = try fixture()
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
        fixture.transport.responses = [.failure(CancellationError())]
        do {
            _ = try await fixture.store.createCandidate(candidate)
            XCTFail("Cancelled upload was treated as acknowledged")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(fixture.transport.requests.map(\.method), ["POST"])
    }

    func testExactReadPreservesLegacyEnvelopeAfterGoogleEmailRename() async throws {
        let fixture = try fixture()
        let original = try generation()
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: original)
        fixture.oauth.current = try authorization(email: "renamed@example.com")
        fixture.transport.responses = [.success(.init(statusCode: 200, body: try metadata(candidate))),
                                       .success(.init(statusCode: 200, body: candidate.bytes))]
        let read = try await fixture.store.readCandidate(
            fileID: fileID, expectedContext: candidate.context, expectedSha256: candidate.sha256
        )
        XCTAssertEqual(try PasskeyBackupGenerationV1Format.encode(XCTUnwrap(read)), candidate.bytes)
        XCTAssertEqual(read?.envelope.accountName, "alice@example.com")
        XCTAssertEqual(read?.envelope.encryptedPayload, original.envelope.encryptedPayload)
        XCTAssertEqual(fixture.oauth.refreshes, 2)
        XCTAssertEqual(fixture.transport.requests.map(\.method), ["GET", "GET"])
    }

    func testAccountSwitchBetweenMetadataAndMediaCannotReadWithOtherBearer() async throws {
        let fixture = try fixture()
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
        fixture.transport.responses = [.success(.init(statusCode: 200, body: try metadata(candidate)))]
        fixture.transport.afterRequest = { _ in fixture.oauth.current = try! self.authorization(subject: "other-subject") }
        await assertFailure { _ = try await fixture.store.readCandidate(
            fileID: self.fileID, expectedContext: candidate.context, expectedSha256: candidate.sha256
        ) }
        XCTAssertEqual(fixture.transport.requests.count, 1)
        XCTAssertEqual(fixture.oauth.refreshes, 1)
    }

    func testInitialAccountSwitchMissingScopeOrInvalidTokenDenyBeforeNetwork() async throws {
        for invalid in try [authorization(subject: "other-subject"), authorization(scopes: []),
                            authorization(expiresAt: Date(timeIntervalSince1970: 1)), authorization(token: "bad\r\ntoken")] {
            let fixture = try fixture()
            let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
            fixture.oauth.current = invalid
            await assertFailure { _ = try await fixture.store.createCandidate(candidate) }
            XCTAssertTrue(fixture.transport.requests.isEmpty)
        }
    }

    func testWrongStorageSubjectAndInvalidPathOrDigestDenyBeforeOAuth() async throws {
        let fixture = try fixture()
        let wrong = try generation(subject: "other-subject")
        XCTAssertThrowsError(try fixture.store.prepareCandidate(fileID: fileID, generation: wrong))
        XCTAssertThrowsError(try fixture.store.prepareCandidate(fileID: "../id", generation: generation()))
        let context = try generation().context
        for pair in [("../id", String(repeating: "a", count: 64)), (fileID, "not-a-digest")] {
            await assertFailure { _ = try await fixture.store.readCandidate(
                fileID: pair.0, expectedContext: context, expectedSha256: pair.1
            ) }
        }
        XCTAssertEqual(fixture.oauth.refreshes, 0)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
    }

    func testMetadataRejectsEveryIdentitySizeSpaceAndPropertySubstitutionBeforeMedia() async throws {
        let fixture = try fixture()
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
        let valid = try metadataObject(candidate)
        var mutations: [[String: Any]] = []
        for (key, value): (String, Any) in [
            ("id", "other"), ("name", "other.bin"), ("mimeType", "text/plain"), ("spaces", ["drive"]),
            ("spaces", ["appDataFolder", "appDataFolder"]), ("size", 785), ("size", "0785"), ("size", "0"),
            ("size", "524289"), ("size", "9223372036854775808"), ("size", "-1"), ("extra", "value")
        ] {
            var changed = valid; changed[key] = value; mutations.append(changed)
        }
        for key in ["format", "namespaceSha256", "generationId", "bundleSha256"] {
            var changed = valid
            var properties = try XCTUnwrap(valid["appProperties"] as? [String: String])
            properties[key] = "substituted"
            changed["appProperties"] = properties
            mutations.append(changed)
        }
        for mutation in mutations {
            fixture.transport.requests = []
            fixture.transport.responses = [.success(.init(statusCode: 200, body: try json(mutation)))]
            await assertFailure { _ = try await fixture.store.readCandidate(
                fileID: self.fileID, expectedContext: candidate.context, expectedSha256: candidate.sha256
            ) }
            XCTAssertEqual(fixture.transport.requests.count, 1)
        }
    }

    func testMetadataRejectsDuplicateNestedKeysOversizeAndTrailingJSON() async throws {
        let fixture = try fixture()
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
        let valid = String(decoding: try metadata(candidate), as: UTF8.self)
        let responses = [valid + "{}", valid.replacingOccurrences(of: "\"format\":", with: "\"format\":\"FPBKGEN1\",\"format\":"),
                         valid.replacingOccurrences(of: "\"id\":", with: "\"id\":\"other\",\"\\u0069d\":"),
                         String(repeating: " ", count: 8193)]
        for text in responses {
            fixture.transport.requests = []
            fixture.transport.responses = [.success(.init(statusCode: 200, body: Data(text.utf8)))]
            await assertFailure { _ = try await fixture.store.readCandidate(
                fileID: self.fileID, expectedContext: candidate.context, expectedSha256: candidate.sha256
            ) }
            XCTAssertEqual(fixture.transport.requests.count, 1)
        }
    }

    func testReadRejectsWrongLengthDigestAndContextEvenWithMatchingMetadata() async throws {
        let fixture = try fixture()
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
        var tampered = candidate.bytes; tampered[tampered.count - 1] ^= 1
        for bytes in [candidate.bytes.dropLast(), candidate.bytes + Data([0]), tampered] {
            fixture.transport.responses = [.success(.init(statusCode: 200, body: try metadata(candidate))),
                                           .success(.init(statusCode: 200, body: Data(bytes)))]
            await assertFailure { _ = try await fixture.store.readCandidate(
                fileID: self.fileID, expectedContext: candidate.context, expectedSha256: candidate.sha256
            ) }
        }
        let foreign = try fixture.store.prepareCandidate(fileID: fileID, generation: generation(epoch: 8))
        var spoof = try metadataObject(candidate)
        var properties = try XCTUnwrap(spoof["appProperties"] as? [String: String])
        properties["bundleSha256"] = foreign.sha256; spoof["appProperties"] = properties
        fixture.transport.responses = [.success(.init(statusCode: 200, body: try json(spoof))),
                                       .success(.init(statusCode: 200, body: foreign.bytes))]
        await assertFailure { _ = try await fixture.store.readCandidate(
            fileID: self.fileID, expectedContext: candidate.context, expectedSha256: foreign.sha256
        ) }
    }

    func testObserved404NeverAllocatesRetriesOrDeletes() async throws {
        for missingMedia in [false, true] {
            let fixture = try fixture()
            let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation())
            fixture.transport.responses = missingMedia ? [.success(.init(statusCode: 200, body: try metadata(candidate))),
                                                          .success(.init(statusCode: 404))] : [.success(.init(statusCode: 404))]
            let read = try await fixture.store.readCandidate(
                fileID: fileID, expectedContext: candidate.context, expectedSha256: candidate.sha256
            )
            XCTAssertNil(read)
            XCTAssertEqual(fixture.transport.requests.map(\.method), missingMedia ? ["GET", "GET"] : ["GET"])
        }
    }

    func testMaximumLegacyEnvelopeFitsGenerationAndLegacyTransportBoundRemainsUnchanged() async throws {
        let fixture = try fixture()
        let generation = try generation(maximumEnvelope: true)
        XCTAssertEqual(generation.envelope.encryptedPayload.count, 256 * 1024)
        let candidate = try fixture.store.prepareCandidate(fileID: fileID, generation: generation)
        XCTAssertGreaterThan(candidate.size, 256 * 1024)
        XCTAssertLessThan(candidate.size, 512 * 1024)
        let account = try GoogleDriveBackupAccount(subject: subject, email: "alice@example.com")
        let defaultStore = try GoogleDrivePasskeyGenerationStorage(
            account: account, tokenProvider: GoogleDrivePasskeyBackupTokenProvider(account: account, session: fixture.oauth)
        )
        XCTAssertEqual(try defaultStore.prepareCandidate(fileID: fileID, generation: generation).bytes, candidate.bytes)
        XCTAssertEqual(fixture.oauth.refreshes, 0)
        fixture.transport.responses = [.success(.init(statusCode: 200, body: try metadata(candidate))),
                                       .success(.init(statusCode: 200, body: candidate.bytes))]
        let read = try await fixture.store.readCandidate(
            fileID: fileID, expectedContext: candidate.context, expectedSha256: candidate.sha256
        )
        XCTAssertEqual(read?.envelope.encryptedPayload, generation.envelope.encryptedPayload)
        XCTAssertEqual(PasskeyBackupHTTPTransportPolicy.maximumResponseBytes, 256 * 1024)
        XCTAssertThrowsError(try URLSessionPasskeyBackupHTTPTransport(maximumResponseBytes: 256 * 1024 + 1))
    }

    func testGenerationURLSessionAcceptsExactCapAndRejectsDeclaredAndStreamedOverflow() async throws {
        for mode in ["exact", "declared", "streamed"] {
            GenerationURLProtocol.install { instance, request in
                let headers = mode == "declared" ? ["Content-Length": "524289"] : [:]
                instance.respond(
                    request: request,
                    headers: headers,
                    chunks: mode == "declared" ? [] : [Data(repeating: 1, count: 524_288)] +
                        (mode == "streamed" ? [Data([2])] : [])
                )
            }
            defer { GenerationURLProtocol.reset() }
            let transport = URLSessionPasskeyGenerationTransport(configuration: configuration())
            do {
                let response = try await transport.execute(transportRequest())
                XCTAssertEqual(mode, "exact")
                XCTAssertEqual(response.body.count, 524_288)
            } catch {
                XCTAssertNotEqual(mode, "exact")
                XCTAssertEqual(error as? PasskeyBackupError, .challengeServiceResponseTooLarge)
            }
            XCTAssertEqual(transport.inFlightRequestCount, 0)
        }
    }

    func testGenerationTransportUsesSingleBodyStreamAndRefusesRedirectReplayAndAmbientAuthentication() async throws {
        let body = Data("opaque fixture bytes".utf8)
        GenerationURLProtocol.install { instance, request in
            XCTAssertNil(request.httpBody)
            XCTAssertNotNil(request.httpBodyStream)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Length"), String(body.count))
            instance.respond(request: request, chunks: [])
        }
        defer { GenerationURLProtocol.reset() }
        let transport = URLSessionPasskeyGenerationTransport(configuration: configuration())
        _ = try await transport.execute(transportRequest(method: "POST", body: body))
        let delegate = PasskeyBackupGenerationSessionDelegate()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: transportRequest().url)
        delegate.urlSession(session, task: task, needNewBodyStream: { XCTAssertNil($0) })
        if #available(iOS 17.0, *) {
            delegate.urlSession(session, task: task, needNewBodyStreamFrom: 1, completionHandler: { XCTAssertNil($0) })
        }
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: HTTPURLResponse(
            url: transportRequest().url, statusCode: 307, httpVersion: nil, headerFields: nil
        )!, newRequest: URLRequest(url: URL(string: "https://foreign.example/")!)) { XCTAssertNil($0) }
        let challenge = URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpace(
                host: "www.googleapis.com", port: 443, protocol: "https", realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: GenerationChallengeSender()
        )
        delegate.urlSession(session, task: task, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .cancelAuthenticationChallenge); XCTAssertNil(credential)
        }
    }

    func testGenerationTransportCancellationReleasesPendingRequest() async throws {
        let started = expectation(description: "started")
        GenerationURLProtocol.install { _, _ in started.fulfill() }
        defer { GenerationURLProtocol.reset() }
        let transport = URLSessionPasskeyGenerationTransport(configuration: configuration())
        let task = Task { try await transport.execute(transportRequest()) }
        await fulfillment(of: [started], timeout: 5)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    func testGenerationTransportRejectsMutationMethodsAndForeignOriginsBeforeNetwork() async throws {
        let transport = URLSessionPasskeyGenerationTransport(configuration: configuration())
        for request in [transportRequest(method: "PATCH"), transportRequest(method: "DELETE"),
                        PasskeyBackupHTTPRequest(method: "GET", url: URL(string: "https://foreign.example/")!),
                        PasskeyBackupHTTPRequest(method: "GET", url: URL(string: "http://www.googleapis.com/")!)] {
            await assertFailure { _ = try await transport.execute(request) }
        }
    }

    private func fixture() throws -> GenerationFixture {
        let account = try GoogleDriveBackupAccount(subject: subject, email: "alice@example.com")
        let oauth = GenerationOAuthFixture(current: try authorization())
        let provider = GoogleDrivePasskeyBackupTokenProvider(account: account, session: oauth)
        let transport = GenerationTransportFixture()
        return try GenerationFixture(oauth: oauth, transport: transport, store: GoogleDrivePasskeyGenerationStorage(
            account: account, tokenProvider: provider, transport: transport
        ))
    }

    private func authorization(
        subject: String = "google-subject-123", email: String = "alice@example.com",
        scopes: Set<String> = [GoogleDrivePasskeyBackupCloudStorage.appDataScope],
        expiresAt: Date = Date().addingTimeInterval(3600), token: String = "fixture-token"
    ) throws -> GoogleDriveBackupAuthorization {
        try GoogleDriveBackupAuthorization(
            account: GoogleDriveBackupAccount(subject: subject, email: email),
            clientID: "fixture-client",
            scopes: scopes,
            accessToken: token,
            expiresAt: expiresAt
        )
    }

    private func generation(
        subject: String = "google-subject-123",
        epoch: Int64 = 7,
        maximumEnvelope: Bool = false
    ) throws -> PasskeyBackupGenerationV1 {
        let owner = "owner:ERERERERERERERERERERERERERERERERERERERERERE"
        let metadata = try PasskeyBackupEnvelopeMetadata(
            storageKey: "wallet-1234",
            walletId: "wallet-001",
            accountName: "alice@example.com",
            createdAtMillis: 1_767_225_600_000
        )
        let payload = try maximumEnvelope ? AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
            Data(repeating: 1, count: 256 * 1024 - 44), metadata: metadata, key: Data(repeating: 0x77, count: 32)
        ) : PasskeyBackupContract.decodeBase64URL(
            "RlBCS0FFQUQBAQwQAAAAHQABAgMEBQYHCAkKC83JBCkpwJEyw__KPV-GpFaKNXesucIWrPbymd1fJxz0FX_uLctQsHJRM3AfVA"
        )
        let envelope = try PasskeyBackupEncryptedRecord(
            storageKey: metadata.storageKey,
            walletId: metadata.walletId,
            accountName: metadata.accountName,
            createdAtMillis: metadata.createdAtMillis,
            encryptedPayload: payload
        )
        let wrapper = try PasskeyBackupCredentialKeyWrapperRecord(
            context: PasskeyBackupKeyWrapperContext(
                ownerSubject: owner, credentialId: "IiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI", keyEpoch: epoch,
                envelopeMetadata: metadata
            ),
            prfSalt: Data(repeating: 0x33, count: 32),
            hkdfSalt: Data(repeating: 0x44, count: 32),
            nonce: Data(repeating: 0x55, count: 12),
            ciphertextAndTag: PasskeyBackupContract.decodeBase64URL(
                "m_xnd6ezMk5VjmGJjqjAVrBDJYQTp7NxcktIT8CmyM8uzo4ZphIMYP-2QRflGgs5"
            )
        )
        return try PasskeyBackupGenerationV1(context: PasskeyBackupGenerationV1.Context(
            ownerSubject: owner, backupNamespace: "backup:iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIg",
            generationId: "mZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZk",
            parentHeadRevision: 6, parentHeadSha256: String(repeating: "a", count: 64), keyEpoch: epoch,
            storageAccountBinding: PasskeyBackupGenerationV1Format.storageAccountBinding(verifiedGoogleSubject: subject)
        ), envelope: envelope, wrappers: [wrapper])
    }

    private func metadataObject(_ candidate: GoogleDrivePasskeyGenerationStorage.Candidate) throws -> [String: Any] {
        ["id": candidate.fileID, "name": "fearless-passkey-generation-\(candidate.context.generationId).bin",
         "mimeType": "application/octet-stream", "spaces": ["appDataFolder"], "size": String(candidate.size),
         "appProperties": ["format": "FPBKGEN1", "generationId": candidate.context.generationId,
                           "bundleSha256": candidate.sha256,
                           "namespaceSha256": PasskeyBackupGenerationV1Format.sha256(Data(candidate.context.backupNamespace.utf8))]]
    }

    private func metadata(_ candidate: GoogleDrivePasskeyGenerationStorage.Candidate) throws -> Data {
        try json(metadataObject(candidate))
    }

    private func json(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }

    private func assertFailure(_ action: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("Unexpected success", file: file, line: line) } catch {}
    }

    private func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GenerationURLProtocol.self]
        return configuration
    }

    private func transportRequest(method: String = "GET", body: Data? = nil) -> PasskeyBackupHTTPRequest {
        PasskeyBackupHTTPRequest(method: method, url: URL(string: "https://www.googleapis.com/drive/v3/files/id?alt=media")!, body: body)
    }
}

private struct GenerationFixture {
    let oauth: GenerationOAuthFixture
    let transport: GenerationTransportFixture
    let store: GoogleDrivePasskeyGenerationStorage
}

@MainActor
private final class GenerationOAuthFixture: GoogleDriveBackupOAuthSession {
    let clientID = "fixture-client"
    var current: GoogleDriveBackupAuthorization
    var refreshes = 0
    init(current: GoogleDriveBackupAuthorization) { self.current = current }
    func currentAuthorization() throws -> GoogleDriveBackupAuthorization? { current }
    func requestConsent(presenting _: UIViewController) async throws -> GoogleDriveBackupAuthorization { current }
    func refreshAuthorization() async throws -> GoogleDriveBackupAuthorization { refreshes += 1; return current }
}

private final class GenerationTransportFixture: PasskeyBackupHTTPTransport {
    var requests: [PasskeyBackupHTTPRequest] = []
    var responses: [Result<PasskeyBackupHTTPResponse, Error>] = []
    var afterRequest: ((PasskeyBackupHTTPRequest) -> Void)?
    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        requests.append(request)
        afterRequest?(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return try responses.removeFirst().get()
    }
}

private final class GenerationURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var handler: ((GenerationURLProtocol, URLRequest) -> Void)?
    static func install(_ handler: @escaping (GenerationURLProtocol, URLRequest) -> Void) {
        lock.lock(); self.handler = handler; lock.unlock()
    }

    static func reset() { lock.lock(); handler = nil; lock.unlock() }
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let handler = Self.handler; Self.lock.unlock()
        handler?(self, request)
    }

    override func stopLoading() {}
    func respond(request: URLRequest, headers: [String: String] = [:], chunks: [Data]) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )!, cacheStoragePolicy: .notAllowed)
        chunks.forEach { client?.urlProtocol(self, didLoad: $0) }
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class GenerationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_: URLCredential, for _: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for _: URLAuthenticationChallenge) {}
    func cancel(_: URLAuthenticationChallenge) {}
}
