import XCTest
@testable import fearless

final class UniversalWalletIdentityTests: XCTestCase {
    func testValidatesAndSerializesActiveUniversalWalletIdentity() throws {
        let identity = activeIdentity()

        XCTAssertTrue(identity.validationErrors().isEmpty)
        XCTAssertEqual(try identity.requireValid(), identity)

        let json = String(decoding: try JSONEncoder().encode(identity), as: UTF8.self)
        XCTAssertTrue(json.contains(#""schemaVersion":2"#))
        XCTAssertTrue(json.contains(#""source":"created-24-word""#))
        XCTAssertTrue(json.contains(#""status":"active""#))
        XCTAssertTrue(json.contains(#""ecosystem":"bitcoin""#))
    }

    func testRejectsPartialActiveWalletsAndDuplicateAccounts() {
        let partial = activeIdentity(
            accounts: Self.defaultAccounts().filter { $0.ecosystem != UniversalWalletEcosystem.iroha.rawValue }
        )
        let duplicate = activeIdentity(
            accounts: Self.defaultAccounts() + [
                Self.defaultAccounts()[0]
            ]
        )

        XCTAssertTrue(partial.validationErrors().contains(.missingActiveEcosystem))
        XCTAssertTrue(duplicate.validationErrors().contains(.duplicateAccountId))
    }

    func testRejectsMalformedIdentityAndAccountFields() {
        let account = UniversalWalletIdentity.PublicAccount(
            accountId: "../bad",
            ecosystem: "unknown",
            address: " bc1bad ",
            chainId: "../bad",
            derivationPath: "m/44'/0'/x",
            publicKeyHex: "ABC"
        )
        let identity = activeIdentity(
            walletId: "bad",
            displayName: "bad\u{0000}name",
            accounts: [account],
            createdAtMillis: 10,
            updatedAtMillis: 9
        )

        let errors = identity.validationErrors()

        XCTAssertTrue(errors.contains(.invalidWalletId))
        XCTAssertTrue(errors.contains(.invalidDisplayName))
        XCTAssertTrue(errors.contains(.invalidTimestamps))
        XCTAssertTrue(errors.contains(.invalidAccountId))
        XCTAssertTrue(errors.contains(.invalidEcosystem))
        XCTAssertTrue(errors.contains(.invalidAddress))
        XCTAssertTrue(errors.contains(.invalidChainId))
        XCTAssertTrue(errors.contains(.invalidDerivationPath))
        XCTAssertTrue(errors.contains(.invalidPublicKeyHex))
        XCTAssertThrowsError(try identity.requireValid())
    }

    func testEnforcesLegacyExportOnlySourceAndReason() {
        let legacy = activeIdentity(
            source: .legacyImport,
            status: .legacyExportOnly,
            accounts: [Self.defaultAccounts()[0]],
            legacyExportOnlyReason: "pre-cutoff account export"
        )
        let wrongSource = activeIdentity(
            source: .created24Word,
            status: .legacyExportOnly,
            accounts: [Self.defaultAccounts()[0]],
            legacyExportOnlyReason: "pre-cutoff account export"
        )
        let missingReason = activeIdentity(
            source: .legacyImport,
            status: .legacyExportOnly,
            accounts: [Self.defaultAccounts()[0]],
            legacyExportOnlyReason: " "
        )
        let activeWithReason = activeIdentity(legacyExportOnlyReason: "not allowed")

        XCTAssertTrue(legacy.validationErrors().isEmpty)
        XCTAssertTrue(wrongSource.validationErrors().contains(.invalidLegacySource))
        XCTAssertTrue(missingReason.validationErrors().contains(.legacyReasonRequired))
        XCTAssertTrue(activeWithReason.validationErrors().contains(.legacyReasonNotAllowed))
    }

    func testAllowsMigrationRequiredIdentityToBePartialButNotEmpty() {
        let migrating = activeIdentity(
            status: .migrationRequired,
            accounts: [Self.defaultAccounts()[0]]
        )
        let emptyMigrating = activeIdentity(status: .migrationRequired, accounts: [])

        XCTAssertFalse(migrating.validationErrors().contains(.missingActiveEcosystem))
        XCTAssertTrue(migrating.validationErrors().isEmpty)
        XCTAssertTrue(emptyMigrating.validationErrors().contains(.publicAccountsRequired))
    }

    private func activeIdentity(
        walletId: String = "uw2_1234567890abcdef",
        displayName: String = "Fearless Universal",
        source: UniversalWalletIdentity.Source = .created24Word,
        status: UniversalWalletIdentity.Status = .active,
        accounts: [UniversalWalletIdentity.PublicAccount] = UniversalWalletIdentityTests.defaultAccounts(),
        createdAtMillis: Int64 = 1_710_000_000_000,
        updatedAtMillis: Int64? = nil,
        legacyExportOnlyReason: String? = nil
    ) -> UniversalWalletIdentity {
        UniversalWalletIdentity(
            walletId: walletId,
            displayName: displayName,
            source: source,
            status: status,
            publicAccounts: accounts,
            createdAtMillis: createdAtMillis,
            updatedAtMillis: updatedAtMillis,
            legacyExportOnlyReason: legacyExportOnlyReason
        )
    }

    private static func defaultAccounts() -> [UniversalWalletIdentity.PublicAccount] {
        [
            UniversalWalletIdentity.PublicAccount(
                accountId: "substrate-polkadot",
                ecosystem: .substrate,
                address: "15FKRtF6nX3SE4PaW4LX69XqYHq2oSep9JX5KF4cgN1XkZ4q",
                chainId: "polkadot",
                derivationPath: UniversalWalletDerivationPaths.substrateRoot,
                publicKeyHex: hex32
            ),
            UniversalWalletIdentity.PublicAccount(
                accountId: "evm-default",
                ecosystem: .evm,
                address: "0x1111111111111111111111111111111111111111",
                chainId: "eip155:1",
                derivationPath: UniversalWalletDerivationPaths.evmDefault
            ),
            UniversalWalletIdentity.PublicAccount(
                accountId: "bitcoin-mainnet",
                ecosystem: .bitcoin,
                address: "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
                chainId: "bitcoin:mainnet",
                derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive
            ),
            UniversalWalletIdentity.PublicAccount(
                accountId: "solana-mainnet",
                ecosystem: .solana,
                address: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk",
                chainId: "solana:mainnet",
                derivationPath: UniversalWalletDerivationPaths.solanaDefault,
                publicKeyHex: hex32
            ),
            UniversalWalletIdentity.PublicAccount(
                accountId: "ton-mainnet",
                ecosystem: .ton,
                address: "UQDxAUFadQXDd3EXGa3TLF_EF66gMc9h3_aZ0j0zXNoIYUCc",
                chainId: "ton:mainnet",
                derivationPath: UniversalWalletDerivationPaths.tonDefault,
                publicKeyHex: hex32
            ),
            UniversalWalletIdentity.PublicAccount(
                accountId: "iroha-taira",
                ecosystem: .iroha,
                address: "testuﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱﾇﾆｲMﾒSﾏﾑヱﾇJヱFmJﾇMs6YN687Y",
                chainId: "iroha3-taira",
                derivationPath: UniversalWalletDerivationPaths.irohaDefault,
                publicKeyHex: hex32
            )
        ]
    }

    private static let hex32 = String(repeating: "11", count: 32)
}
