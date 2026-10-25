import MocksBasket
import XCTest

@testable import SSFCloudStorage

final class BackupFileFactoryTests: XCTestCase {
    func testBackupFileFactoryInit() {
        // arrange
        let service = EncryptionServiceProtocolMock()

        // act
        let factory = BackupFileFactory(service: service)

        // assert
        XCTAssertNotNil(factory)
    }

    func testCreateFileWithMock() throws {
        // arrange
        let service = EncryptionServiceProtocolMock()
        service
            .createEncryptedDataWithMessageReturnValue = try Data(hexStringSSF: TestData.hexString)

        // act
        let factory = BackupFileFactory(service: service)
        let url = try factory.createFile(from: TestData.account, password: "1")
        let data = try Data(contentsOf: url)
        let account = try JSONDecoder().decode(EcryptedBackupAccount.self, from: data)

        // assert
        XCTAssertEqual(data.count, 1260)
        XCTAssertEqual(account.name, TestData.account.name)
    }

    func testCreateFile() throws {
        // arrange
        let service = EncryptionService()

        // act
        let factory = BackupFileFactory(service: service)
        let url = try factory.createFile(from: TestData.account, password: "1")
        let data = try Data(contentsOf: url)
        let account = try JSONDecoder().decode(EcryptedBackupAccount.self, from: data)

        // assert
        XCTAssertEqual(account.name, TestData.account.name)
        XCTAssertEqual(account.address, TestData.account.address)
        XCTAssertEqual(account.cryptoType, TestData.account.cryptoType)
        XCTAssertEqual(account.json, TestData.account.json)
        XCTAssertEqual(account.encryptedSeed, TestData.account.encryptedSeed)
    }
}

extension BackupFileFactoryTests {
    enum TestData {
        static let hexString = "0xbf57a61b1d24b6cde5a12f6779e9d13f7c59db72fc2a63bd382a6c91e7e41f61"

        static let substrateJson = """
        {\"address\":\"cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ\",\"encoded\":\"AAUbK8HDAE7Mw26rox6dktexv9pG5MRk\\/WtCJFtV2+kAgAAAAQAAAAgAAACivZKIFh9rMwauWG97MJ0ONwPg6eOpXNygK6X9RQfKMPvETRAfpHbRJp42LKEeWDNczqKaxltMj3yeMUi9kOYIz1sXMt7g7PC7aHUvSsF2G8nzV+XrNpC7nc8s+ty1OmVeKJWsSACfNj3OW9gxesmAtpfSrWx2ppSviKwvU1SKNYPfq+rxFCG+sXx4lggOFouAmT5iaPTL9fck\\/1vI\",\"encoding\":{\"content\":[\"pkcs8\",\"sr25519\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"meta\":{\"genesisHash\":\"0xded5a658e6ff2c82ce640caf8910ea2bb700aad5511ec7c3014cc7c256f5d956\",\"name\":\"chop\",\"whenCreated\":1706609064}}
        """

        static let account = OpenBackupAccount(
            name: "chop",
            address: "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ",
            passphrase: "carpet shiver bacon dirt sadness hammer isolate window hope lounge humble kitten",
            cryptoType: "SR25519",
            substrateDerivationPath: nil,
            ethDerivationPath: nil,
            backupAccountType: [.passphrase, .json, .seed],
            json: OpenBackupAccount
                .Json(substrateJson: substrateJson),
            encryptedSeed: OpenBackupAccount.Seed()
        )
    }
}
