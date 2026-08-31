import CryptoKit
import XCTest
@testable import fearless

final class IrohaConnectAccountProviderTests: XCTestCase {
    func testSelectedAccountReturnsOnlyPublicDescriptor() throws {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
        let descriptor = IrohaConnectAccountDescriptor(
            walletName: "Sakura",
            accountID: "iroha-account",
            publicKey: key.publicKey.rawRepresentation
        )
        let provider = KeychainIrohaConnectAccountProvider {
            (descriptor, key.rawRepresentation)
        }

        XCTAssertEqual(try provider.selectedAccount(), descriptor)
    }

    func testSelectedAccountDoesNotLoadPrivateMaterialWhenDescriptorLoaderIsAvailable() throws {
        let descriptor = IrohaConnectAccountDescriptor(
            walletName: "Sakura",
            accountID: "iroha-account",
            publicKey: Data(repeating: 3, count: 32)
        )
        var loadedPrivateMaterial = false
        let provider = KeychainIrohaConnectAccountProvider(
            descriptorLoader: { descriptor },
            materialLoader: {
                loadedPrivateMaterial = true
                return (descriptor, Data(repeating: 4, count: 32))
            }
        )

        XCTAssertEqual(try provider.selectedAccount(), descriptor)
        XCTAssertFalse(loadedPrivateMaterial)
    }

    func testSignProducesVerifiableEd25519Signature() throws {
        let seed = Data(repeating: 9, count: 32)
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let descriptor = IrohaConnectAccountDescriptor(
            walletName: "Sakura",
            accountID: "iroha-account",
            publicKey: key.publicKey.rawRepresentation
        )
        let provider = KeychainIrohaConnectAccountProvider {
            (descriptor, key.rawRepresentation)
        }
        let message = Data("canonical Uranai contract call".utf8)

        let signature = try provider.sign(message, for: descriptor)

        let verifier = try Curve25519.Signing.PublicKey(rawRepresentation: descriptor.publicKey)
        XCTAssertTrue(verifier.isValidSignature(signature, for: message))
        XCTAssertEqual(key.rawRepresentation, seed)
        XCTAssertEqual(key.publicKey.rawRepresentation, descriptor.publicKey)
    }

    func testSignRejectsAccountChangedAfterApproval() throws {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 11, count: 32))
        let descriptor = IrohaConnectAccountDescriptor(
            walletName: "Sakura",
            accountID: "iroha-account",
            publicKey: key.publicKey.rawRepresentation
        )
        let provider = KeychainIrohaConnectAccountProvider {
            (descriptor, key.rawRepresentation)
        }
        let changed = IrohaConnectAccountDescriptor(
            walletName: descriptor.walletName,
            accountID: "different-account",
            publicKey: descriptor.publicKey
        )

        XCTAssertThrowsError(try provider.sign(Data([1]), for: changed)) { error in
            XCTAssertEqual(error as? IrohaConnectAccountProviderError, .accountMismatch)
        }
    }
}

final class IrohaConnectPromptTests: XCTestCase {
    func testSignaturePromptSummarizesPayloadWithoutDisplayingIt() {
        let payload = Data("private contract signing bytes".utf8)
        let prompt = IrohaConnectPrompt(
            kind: .signature(payload: payload),
            appName: "Uranai",
            appURL: URL(string: "https://uranai.app"),
            networkName: "Taira Testnet",
            accountID: "account"
        )

        XCTAssertEqual(prompt.payloadByteCount, payload.count)
        XCTAssertEqual(prompt.payloadDigest?.count, 64)
        XCTAssertFalse(prompt.payloadDigest?.contains("private") == true)
    }

    func testConnectionPromptHasNoPayloadSummary() {
        let prompt = IrohaConnectPrompt(
            kind: .connection,
            appName: "Uranai",
            appURL: nil,
            networkName: "Taira Testnet",
            accountID: "account"
        )

        XCTAssertNil(prompt.payloadByteCount)
        XCTAssertNil(prompt.payloadDigest)
    }

    func testShortenedAccountPreservesSmallAccountAndBothEndsOfLongAccount() {
        XCTAssertEqual(IrohaConnectPrompt.shortenedAccountID("short"), "short")
        XCTAssertEqual(
            IrohaConnectPrompt.shortenedAccountID("abcdefghijklmnopqrstuvwxzy0123456789"),
            "abcdefghijkl…0123456789"
        )
    }
}

final class IrohaConnectURLHandlerTests: XCTestCase {
    func testHandle_whenIrohaConnectURLMatches_thenStartsSessionOnMainQueue() throws {
        let started = expectation(description: "Starts IrohaConnect session")
        let expectedURL = try XCTUnwrap(URL(string: "irohaconnect://connect?pairing=test"))
        let handler = IrohaConnectURLHandler { url in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(url, expectedURL)
            started.fulfill()
        }

        XCTAssertTrue(handler.handle(url: expectedURL))
        wait(for: [started], timeout: 1)
    }

    func testHandle_whenURLDoesNotMatch_thenLeavesItForOtherHandlers() throws {
        var didStart = false
        let handler = IrohaConnectURLHandler { _ in
            didStart = true
        }
        let unrelatedURL = try XCTUnwrap(URL(string: "fearless://connect"))

        XCTAssertFalse(handler.handle(url: unrelatedURL))
        XCTAssertFalse(didStart)
    }
}
