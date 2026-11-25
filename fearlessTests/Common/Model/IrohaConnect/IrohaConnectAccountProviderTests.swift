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

    // Signing is compiled off in production (IOSUX-1); these tests keep the
    // signing path itself covered for when the safe design re-enables it.
    #if DEBUG
        func testSignProducesVerifiableEd25519Signature() throws {
            let seed = Data(repeating: 9, count: 32)
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
            let descriptor = IrohaConnectAccountDescriptor(
                walletName: "Sakura",
                accountID: "iroha-account",
                publicKey: key.publicKey.rawRepresentation
            )
            let provider = KeychainIrohaConnectAccountProvider(policy: .enabledForTests) {
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
            let provider = KeychainIrohaConnectAccountProvider(policy: .enabledForTests) {
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
    #endif
}

final class IrohaConnectPromptTests: XCTestCase {
    func testTransactionPromptShowsTheReviewNotRawBytes() {
        let review = IrohaConnectWebVectors.reviewedTransaction("transfer xor").review
        let prompt = IrohaConnectPrompt(
            kind: .transaction(review),
            appName: "Uranai",
            appURL: URL(string: "https://uranai.app"),
            networkName: "Taira Testnet",
            accountID: review.authority
        )

        XCTAssertTrue(prompt.isTransaction)
        XCTAssertEqual(prompt.title, "Approve transfer")
        XCTAssertEqual(prompt.rows.first { $0.label == "SEND" }?.value, "0.001 XOR")
        XCTAssertEqual(prompt.rows.first { $0.label == "CLAIMED ORIGIN" }?.value, "uranai.app")
        XCTAssertFalse(prompt.rows.contains { $0.value.contains(review.payloadHashHex) }, "the full hash is shortened")
    }

    func testConnectionPromptHasNoTransactionRows() {
        let prompt = IrohaConnectPrompt(
            kind: .connection(permissions: nil),
            appName: "Uranai",
            appURL: nil,
            networkName: "Taira Testnet",
            accountID: "account"
        )

        XCTAssertFalse(prompt.isTransaction)
        XCTAssertFalse(prompt.rows.contains { $0.label == "PAYLOAD HASH" || $0.label == "SEND" })
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
