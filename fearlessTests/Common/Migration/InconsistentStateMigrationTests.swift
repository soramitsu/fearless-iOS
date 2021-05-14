import XCTest
@testable import fearless
import SoraKeystore

class InconsistentStateMigrationTests: XCTestCase {

    func testInconsistentStateCleared() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let chain = Chain.westend

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        XCTAssertNotNil(settings.selectedAccount)

        let migrator = InconsistentStateMigrator(
            settings: settings,
            keychain: InMemoryKeychain()
        )

        // when

        try migrator.migrate()

        // then

        XCTAssertNil(settings.selectedAccount)
    }

    func testConsistentStateIsNotCleared() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let chain = Chain.westend

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        guard let expectedAccount = settings.selectedAccount else {
            XCTFail("Unexpected account")
            return
        }

        let migrator = InconsistentStateMigrator(
            settings: settings,
            keychain: keychain
        )

        // when

        try migrator.migrate()

        // then

        let keyExists = try keychain.checkSecretKeyForAddress(expectedAccount.address)

        XCTAssertEqual(expectedAccount, settings.selectedAccount)
        XCTAssertTrue(keyExists)
    }
}
