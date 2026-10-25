import TweetNacl
import XCTest

@testable import SSFCloudStorage

final class EncryptionServiceTests: XCTestCase {
    func testCreateEncryptedData() throws {
        // arrange
        let service = EncryptionService()

        // act
        let encodedPath = try service.createEncryptedData(
            with: "1",
            message: TestData.account.encryptedSubstrateDerivationPath
        )

        // assert
        XCTAssertNotNil(encodedPath)
    }

    func testGetDecryptedWithError() throws {
        // arrange
        let service = EncryptionService()

        // act
        do {
            let seed = try service.getDecrypted(from: TestData.substrateSeed, password: "1")
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                NaclSecretBox.NaclSecretBoxError.creationFailed.localizedDescription
            )
        }
    }
}

extension EncryptionServiceTests {
    enum TestData {
        static let substrateJson = """
        {\"address\":\"cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ\",\"encoded\":\"AAUbK8HDAE7Mw26rox6dktexv9pG5MRk\\/WtCJFtV2+kAgAAAAQAAAAgAAACivZKIFh9rMwauWG97MJ0ONwPg6eOpXNygK6X9RQfKMPvETRAfpHbRJp42LKEeWDNczqKaxltMj3yeMUi9kOYIz1sXMt7g7PC7aHUvSsF2G8nzV+XrNpC7nc8s+ty1OmVeKJWsSACfNj3OW9gxesmAtpfSrWx2ppSviKwvU1SKNYPfq+rxFCG+sXx4lggOFouAmT5iaPTL9fck\\/1vI\",\"encoding\":{\"content\":[\"pkcs8\",\"sr25519\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"meta\":{\"genesisHash\":\"0xded5a658e6ff2c82ce640caf8910ea2bb700aad5511ec7c3014cc7c256f5d956\",\"name\":\"chop\",\"whenCreated\":1706609064}}
        """

        static let substrateSeed = """
        0ffea7239c86f2c57976bb2ae65f0fe183ad40b5450edd2c0f2610aab80e9ae70080000001000000080000009f92ff8b19a2fc6eb7b68b746d9c6b6a21710d82b13704e62a7b90e402b8cd879b4f859f7da243bcc9f9674435e08fcd1a3562e500b99d3e40508bdd34e54819e3b79153097995f687ad3180852a3b1f05a657919ec8dcf2f0f0ed88693e0a263aa7ec0ff1106763e842
        """

        static let account = EcryptedBackupAccount(
            name: "chop",
            address: "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ",
            encryptedMnemonicPhrase: nil,
            encryptedSubstrateDerivationPath: "5944fbdce78478ef92858817b176fe0b5b884e9c8652de8e10061f0680f83c3100800000010000000800000012e34d41a1843fe84e627672c688150b2ab19c12e7d6b77dab91457f3e8f06a1ca66218604f14691",
            encryptedEthDerivationPath: nil,
            cryptoType: "SR25519",
            backupAccountType: [
                "passphrase",
                "json",
                "seed",
            ],
            json: OpenBackupAccount
                .Json(substrateJson: substrateJson),
            encryptedSeed: OpenBackupAccount
                .Seed(substrateSeed: substrateSeed)
        )
    }
}
