import CryptoKit
import XCTest
@testable import FearlessWalletConnect

final class VerifyTests: XCTestCase {
    private let metadata = AppMetadata(name: "Public dApp", description: "", url: "https://public.example/app", icons: [])
    private let message = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8="

    private final class FetchLog: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []

        func record(_ url: URL) {
            lock.lock()
            urls.append(url)
            lock.unlock()
        }

        var all: [URL] {
            lock.lock()
            defer { lock.unlock() }
            return urls
        }
    }

    private struct Signer {
        let key = P256.Signing.PrivateKey()

        var jwk: JSONValue {
            let raw = key.publicKey.rawRepresentation
            return .object([
                "kty": .string("EC"),
                "crv": .string("P-256"),
                "x": .string(Base64.encodeURL(raw.prefix(32))),
                "y": .string(Base64.encodeURL(raw.suffix(32))),
                "ext": .bool(true)
            ])
        }

        func sign(_ claims: [String: JSONValue]) throws -> String {
            let header = Base64.encodeURL(Data(#"{"alg":"ES256","typ":"JWT"}"#.utf8))
            let payload = Base64.encodeURL(JSONSerializer.data(from: .object(claims)))
            let signature = try key.signature(for: Data("\(header).\(payload)".utf8))
            return "\(header).\(payload).\(Base64.encodeURL(signature.rawRepresentation))"
        }
    }

    private func claims(_ overrides: [String: JSONValue] = [:]) -> [String: JSONValue] {
        var claims: [String: JSONValue] = [
            "exp": .int(Int64(Date().timeIntervalSince1970) + 300),
            "id": .string(WalletConnectCrypto.messageHash(message)),
            "origin": .string("https://public.example"),
            "isScam": .bool(false),
            "isVerified": .bool(true)
        ]
        for (key, value) in overrides {
            claims[key] = value
        }
        return claims
    }

    private func verifier(signer: Signer, log: FetchLog, attestationResponse: JSONValue? = nil) -> VerifyClient {
        let jwk = signer.jwk
        return VerifyClient(fetch: { url in
            log.record(url)
            if url.path.hasSuffix("/v3/public-key") {
                let body = JSONValue.object(["publicKey": jwk, "expiresAt": .int(Int64(Date().timeIntervalSince1970) + 3600)])
                return (200, JSONSerializer.data(from: body))
            }
            if let attestationResponse, url.path.contains("/attestation/") {
                return (200, JSONSerializer.data(from: attestationResponse))
            }
            return (404, Data())
        })
    }

    func testASignedAttestationForThisMessageNamesTheOrigin() async throws {
        let signer = Signer()
        let log = FetchLog()
        let verify = verifier(signer: signer, log: log)

        let valid = await verify.context(metadata: metadata, message: message, attestation: try signer.sign(claims()))
        XCTAssertEqual(valid, VerifyContext(origin: "https://public.example", validation: .valid, verifyUrl: "https://verify.walletconnect.org"))

        let phishing = await verify.context(
            metadata: metadata,
            message: message,
            attestation: try signer.sign(claims(["origin": .string("https://phish.example")]))
        )
        XCTAssertEqual(phishing.validation, .invalid)
        XCTAssertEqual(phishing.origin, "https://phish.example")

        let scam = await verify.context(metadata: metadata, message: message, attestation: try signer.sign(claims(["isScam": .bool(true)])))
        XCTAssertEqual(scam.validation, .scam)
        XCTAssertTrue(scam.isScam)

        // The key is fetched once and kept until it expires.
        XCTAssertEqual(log.all.filter { $0.path.hasSuffix("/v3/public-key") }.count, 1)
    }

    func testAnAttestationThatDoesNotHoldLeavesTheOriginUnknown() async throws {
        let signer = Signer()
        let forger = Signer()
        let log = FetchLog()
        let verify = verifier(signer: signer, log: log)

        for attestation in [
            try forger.sign(claims()),
            try signer.sign(claims(["exp": .int(Int64(Date().timeIntervalSince1970) - 1)])),
            try signer.sign(claims(["isVerified": .bool(false)])),
            try signer.sign(claims(["id": .string(WalletConnectCrypto.messageHash("another message"))])),
            "not.a.jwt"
        ] {
            let context = await verify.context(metadata: metadata, message: message, attestation: attestation)
            XCTAssertEqual(context.validation, .unknown, attestation)
            XCTAssertEqual(context.origin, "https://public.example/app")
        }
        // A forged key made the client refresh the Verify key once before giving up.
        XCTAssertGreaterThanOrEqual(log.all.filter { $0.path.hasSuffix("/v3/public-key") }.count, 2)
    }

    func testWithoutAnAttestationTheTrustedServiceIsAskedByTheMessageHash() async throws {
        let log = FetchLog()
        let verify = verifier(
            signer: Signer(),
            log: log,
            attestationResponse: .object(["origin": .string("https://public.example"), "isScam": .bool(false)])
        )
        let claimingOtherServer = AppMetadata(
            name: "Public dApp",
            description: "",
            url: "https://public.example/app",
            icons: [],
            verifyUrl: "https://verify.attacker.example"
        )

        let context = await verify.context(metadata: claimingOtherServer, message: message, attestation: nil)
        XCTAssertEqual(context.validation, .valid)
        XCTAssertEqual(context.verifyUrl, "https://verify.walletconnect.org")
        XCTAssertEqual(
            log.all.last?.absoluteString,
            "https://verify.walletconnect.org/attestation/\(WalletConnectCrypto.messageHash(message))?v2Supported=true"
        )

        // An empty attestation means the dApp has none: nothing is asked.
        let before = log.all.count
        let skipped = await verify.context(metadata: metadata, message: message, attestation: "")
        XCTAssertEqual(skipped.validation, .unknown)
        XCTAssertEqual(log.all.count, before)
    }

    func testTheClientPassesTheContextWithTheProposal() async throws {
        let relay = FakeRelay()
        let signer = Signer()
        let log = FetchLog()
        let wallet = try await makeWallet(relay: relay, verify: verifier(signer: signer, log: log))
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay, url: "https://public.example")

        let uri = try await dapp.propose()
        let held = try XCTUnwrap(relay.publishedMessages(on: uri.topic).first)
        // The relay attaches Verify's attestation of the proposal as it was published.
        let attestation = try signer.sign(claims(["id": .string(WalletConnectCrypto.messageHash(held.message))]))
        relay.attest(topic: uri.topic, attestation: attestation)

        try await wallet.pair(uri: uri)
        _ = try await events.waitForProposal()
        let context = try XCTUnwrap(events.proposals().first?.1)
        XCTAssertEqual(context.validation, .valid)
        XCTAssertEqual(context.origin, "https://public.example")
        XCTAssertEqual(events.proposals().count, 1)
        await dapp.close()
    }
}
