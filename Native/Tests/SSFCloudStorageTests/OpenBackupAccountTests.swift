import XCTest

@testable import SSFCloudStorage

final class OpenBackupAccountTests: XCTestCase {
    func testOpenBackupAccountInit() {
        // arrange
        let expectedAddress = "address"

        // act
        let account = OpenBackupAccount(address: expectedAddress)

        // assert
        XCTAssertNotNil(account)
        XCTAssertNil(account.name)
        XCTAssertEqual(account.address, expectedAddress)
        XCTAssertNil(account.passphrase)
        XCTAssertNil(account.cryptoType)
        XCTAssertNil(account.substrateDerivationPath)
        XCTAssertNil(account.ethDerivationPath)
        XCTAssertNil(account.backupAccountType)
        XCTAssertNil(account.json)
        XCTAssertNil(account.encryptedSeed)
    }

    func testOpenBackupAccountInitWithValues() {
        // arrange
        let expectedAccount = TestData.account

        // act
        let account = OpenBackupAccount(
            name: expectedAccount.name,
            address: expectedAccount.address,
            passphrase: expectedAccount.passphrase,
            cryptoType: expectedAccount.cryptoType,
            substrateDerivationPath: expectedAccount
                .substrateDerivationPath,
            ethDerivationPath: expectedAccount.ethDerivationPath,
            backupAccountType: expectedAccount.backupAccountType,
            json: expectedAccount.json,
            encryptedSeed: expectedAccount.encryptedSeed
        )

        // assert
        XCTAssertNotNil(account)
        XCTAssertEqual(account.name, expectedAccount.name)
        XCTAssertEqual(account.address, expectedAccount.address)
        XCTAssertEqual(account.passphrase, expectedAccount.passphrase)
        XCTAssertEqual(account.cryptoType, expectedAccount.cryptoType)
        XCTAssertEqual(account.substrateDerivationPath, expectedAccount.substrateDerivationPath)
        XCTAssertEqual(account.ethDerivationPath, expectedAccount.ethDerivationPath)
        XCTAssertEqual(account.backupAccountType, expectedAccount.backupAccountType)
        XCTAssertEqual(account.json?.ethJson, expectedAccount.json?.ethJson)
        XCTAssertEqual(account.json?.substrateJson, expectedAccount.json?.substrateJson)
        XCTAssertEqual(
            account.encryptedSeed?.substrateSeed,
            expectedAccount.encryptedSeed?.substrateSeed
        )
        XCTAssertEqual(account.encryptedSeed?.ethSeed, expectedAccount.encryptedSeed?.ethSeed)
    }
}

extension OpenBackupAccountTests {
    enum TestData {
        static let account = OpenBackupAccount(
            name: "name",
            address: "address",
            passphrase: "passphrase",
            cryptoType: "cryptoType",
            substrateDerivationPath: "substrateDerivationPath",
            ethDerivationPath: "ethDerivationPath",
            backupAccountType: [.passphrase, .seed, .json],
            json: OpenBackupAccount.Json(
                substrateJson: "substrateJson",
                ethJson: "ethJson"
            ),
            encryptedSeed: OpenBackupAccount.Seed(
                substrateSeed: "substrateSeed",
                ethSeed: "ethSeed"
            )
        )
    }
}
