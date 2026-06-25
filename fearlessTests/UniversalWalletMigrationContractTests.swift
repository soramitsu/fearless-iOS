import XCTest
import SSFModels
@testable import fearless

final class UniversalWalletMigrationContractTests: XCTestCase {
    private let builder = IOSUniversalWalletMigrationSnapshotBuilder(
        cutoffAtMillis: 1_710_000_000_000,
        clockMillis: { 1_710_000_000_100 }
    )

    func testBlocksNormalAccessWhenLegacyVaultsExistWithoutUniversalWallet() throws {
        let snapshot = migrationSnapshot(hasUniversalWallet: false, legacyVaults: [Self.legacyVault()])

        XCTAssertTrue(snapshot.validationErrors().isEmpty)
        XCTAssertEqual(snapshot.requiredAction(), UniversalWalletMigrationRequiredAction.migrateBeforeAccess)
        XCTAssertFalse(snapshot.allowsNormalWalletAccess())
        XCTAssertTrue(snapshot.allowsLegacySecretExport())

        let json = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        XCTAssertTrue(json.contains(#""platform":"ios""#))
        XCTAssertTrue(json.contains(#""mode":"export-only""#))
        XCTAssertTrue(json.contains(#""canSignTransactions":false"#))
    }

    func testRequiresNewUniversalWalletWhenNoWalletMaterialExists() {
        let snapshot = migrationSnapshot(hasUniversalWallet: false, legacyVaults: [])

        XCTAssertTrue(snapshot.validationErrors().isEmpty)
        XCTAssertEqual(snapshot.requiredAction(), UniversalWalletMigrationRequiredAction.createUniversalWallet)
        XCTAssertFalse(snapshot.allowsNormalWalletAccess())
        XCTAssertFalse(snapshot.allowsLegacySecretExport())
    }

    func testAllowsNormalAccessOnceUniversalWalletExistsWhileKeepingLegacyExportOnly() {
        let snapshot = migrationSnapshot(hasUniversalWallet: true, legacyVaults: [Self.legacyVault()])

        XCTAssertTrue(snapshot.validationErrors().isEmpty)
        XCTAssertEqual(snapshot.requiredAction(), UniversalWalletMigrationRequiredAction.normalAccess)
        XCTAssertTrue(snapshot.allowsNormalWalletAccess())
        XCTAssertTrue(snapshot.allowsLegacySecretExport())
    }

    func testRejectsMalformedMigrationSnapshotsAndLegacyVaults() {
        let badVault = UniversalWalletLegacyVaultDescriptor(
            vaultId: "bad",
            accountId: "../bad",
            ecosystem: "unknown",
            address: " address ",
            displayName: "bad\u{0000}name",
            exportOnlyReason: " ",
            canExportSecrets: false,
            canSignTransactions: true,
            discoveredAtMillis: 10,
            lastExportedAtMillis: 9
        )
        let snapshot = migrationSnapshot(
            schemaVersion: 99,
            legacyVaults: [badVault, badVault],
            cutoffAtMillis: 0,
            evaluatedAtMillis: 0
        )

        let errors = snapshot.validationErrors()

        XCTAssertTrue(errors.contains(.invalidSchemaVersion))
        XCTAssertTrue(errors.contains(.invalidTimestamp))
        XCTAssertTrue(errors.contains(.invalidVaultId))
        XCTAssertTrue(errors.contains(.duplicateVaultId))
        XCTAssertTrue(errors.contains(.invalidAccountId))
        XCTAssertTrue(errors.contains(.invalidEcosystem))
        XCTAssertTrue(errors.contains(.invalidAddress))
        XCTAssertTrue(errors.contains(.invalidDisplayName))
        XCTAssertTrue(errors.contains(.invalidExportReason))
        XCTAssertTrue(errors.contains(.exportDisabled))
        XCTAssertTrue(errors.contains(.legacySigningEnabled))
    }

    func testBuilderRequiresUniversalWalletCreationForEmptyInstall() {
        let snapshot = builder.build(accounts: [])

        XCTAssertFalse(snapshot.hasUniversalWallet)
        XCTAssertTrue(snapshot.legacyVaults.isEmpty)
        XCTAssertEqual(snapshot.requiredAction(), .createUniversalWallet)
        XCTAssertTrue(snapshot.validationErrors().isEmpty)
    }

    func testBuilderCreatesExportOnlyDescriptorsForLegacyRoots() {
        let snapshot = builder.build(accounts: [Self.wallet()])

        XCTAssertFalse(snapshot.hasUniversalWallet)
        XCTAssertEqual(snapshot.requiredAction(), .migrateBeforeAccess)
        XCTAssertEqual(
            snapshot.legacyVaults.map(\.ecosystem),
            [UniversalWalletEcosystem.substrate.rawValue, UniversalWalletEcosystem.evm.rawValue]
        )
        XCTAssertTrue(snapshot.legacyVaults.allSatisfy(\.canExportSecrets))
        XCTAssertTrue(snapshot.legacyVaults.allSatisfy { !$0.canSignTransactions })
        XCTAssertEqual(Set(snapshot.legacyVaults.map(\.vaultId)).count, snapshot.legacyVaults.count)
        XCTAssertTrue(snapshot.validationErrors().isEmpty)
    }

    func testBuilderAllowsNormalAccessForCompleteUniversalWallet() throws {
        let bitcoin = try BitcoinKeyDerivation.deriveAccount(mnemonic: Self.mnemonic, network: .mainnet)
        let solana = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let iroha = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let ton = try TonKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)

        let snapshot = builder.build(
            accounts: [
                Self.wallet(
                    chainAccounts: [
                        Self.chainAccount(
                            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
                            publicKey: bitcoin.publicKey,
                            cryptoType: CryptoType.ecdsa.rawValue
                        ),
                        Self.chainAccount(
                            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
                            publicKey: solana.publicKey
                        ),
                        Self.chainAccount(
                            chainId: UniversalWalletRegistry.taira.chainId,
                            publicKey: iroha.publicKey
                        ),
                        Self.chainAccount(
                            chainId: "ton:mainnet",
                            publicKey: ton.publicKey
                        )
                    ]
                )
            ]
        )

        XCTAssertTrue(snapshot.hasUniversalWallet)
        XCTAssertTrue(snapshot.legacyVaults.isEmpty)
        XCTAssertEqual(snapshot.requiredAction(), .normalAccess)
        XCTAssertTrue(snapshot.validationErrors().isEmpty)
    }

    func testBuilderKeepsPartialUniversalWalletBlockedWithLegacyExports() throws {
        let solana = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let snapshot = builder.build(
            accounts: [
                Self.wallet(
                    chainAccounts: [
                        Self.chainAccount(
                            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
                            publicKey: solana.publicKey
                        )
                    ]
                )
            ]
        )

        XCTAssertFalse(snapshot.hasUniversalWallet)
        XCTAssertEqual(snapshot.requiredAction(), .migrateBeforeAccess)
        XCTAssertEqual(
            snapshot.legacyVaults.map(\.ecosystem),
            [UniversalWalletEcosystem.substrate.rawValue, UniversalWalletEcosystem.evm.rawValue]
        )
        XCTAssertTrue(snapshot.validationErrors().isEmpty)
    }

    func testBuilderKeepsMalformedLegacyDataFailClosedWithValidDescriptor() {
        let snapshot = builder.build(
            accounts: [
                Self.wallet(
                    name: " Bad\u{0000}Name That Is Far Too Long For The Shared Human Text Contract And Must Be Trimmed ",
                    substrateAccountId: Data([1]),
                    ethereumAddress: nil,
                    ethereumPublicKey: Data(repeating: 4, count: 33)
                )
            ]
        )
        let descriptor = snapshot.legacyVaults[0]

        XCTAssertFalse(snapshot.hasUniversalWallet)
        XCTAssertEqual(snapshot.requiredAction(), .migrateBeforeAccess)
        XCTAssertEqual(
            snapshot.legacyVaults.map(\.ecosystem),
            [UniversalWalletEcosystem.substrate.rawValue, UniversalWalletEcosystem.evm.rawValue]
        )
        XCTAssertEqual(descriptor.address, "unavailable:ios:wallet-12345678:substrate")
        XCTAssertEqual(snapshot.legacyVaults[1].address, "unavailable:ios:wallet-12345678:evm")
        XCTAssertFalse(descriptor.displayName?.contains("\u{0000}") ?? true)
        XCTAssertLessThanOrEqual(descriptor.displayName?.count ?? 0, 64)
        XCTAssertTrue(snapshot.validationErrors().isEmpty)
    }

    func testProviderMapsFetchedAccountsToSnapshot() throws {
        let provider = IOSUniversalWalletMigrationSnapshotProvider(builder: builder) { completion in
            completion(.success([Self.wallet()]))
        }
        var result: Result<UniversalWalletMigrationSnapshot, Error>?

        provider.fetchSnapshot { snapshotResult in
            result = snapshotResult
        }

        let snapshot = try XCTUnwrap(result).get()
        XCTAssertEqual(snapshot.requiredAction(), .migrateBeforeAccess)
        XCTAssertEqual(snapshot.evaluatedAtMillis, 1_710_000_000_100)
        XCTAssertTrue(snapshot.validationErrors().isEmpty)
    }

    func testProviderUsesDefaultCutoffForRuntimeFetches() throws {
        let provider = IOSUniversalWalletMigrationSnapshotProvider { completion in
            completion(.success([]))
        }
        var result: Result<UniversalWalletMigrationSnapshot, Error>?

        provider.fetchSnapshot { snapshotResult in
            result = snapshotResult
        }

        let snapshot = try XCTUnwrap(result).get()
        XCTAssertEqual(snapshot.cutoffAtMillis, UniversalWalletMigrationCutoff.defaultAtMillis)
        XCTAssertEqual(snapshot.requiredAction(), .createUniversalWallet)
        XCTAssertTrue(snapshot.validationErrors().isEmpty)
    }

    func testProviderPropagatesFetchFailure() throws {
        let provider = IOSUniversalWalletMigrationSnapshotProvider(builder: builder) { completion in
            completion(.failure(TestFetchError.failed))
        }
        var result: Result<UniversalWalletMigrationSnapshot, Error>?

        provider.fetchSnapshot { snapshotResult in
            result = snapshotResult
        }

        switch try XCTUnwrap(result) {
        case .success:
            XCTFail("Expected provider to propagate account fetch failure")
        case let .failure(error):
            XCTAssertEqual(error as? TestFetchError, .failed)
        }
    }

    func testLegacyExportResolverResolvesSubstrateAndEvmDescriptors() throws {
        let wallet = Self.wallet()
        let substrateDescriptor = try legacyDescriptor(for: .substrate, wallet: wallet)
        let evmDescriptor = try legacyDescriptor(for: .evm, wallet: wallet)

        let substrateTarget = try XCTUnwrap(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: substrateDescriptor,
                accounts: [wallet]
            )
        )
        let evmTarget = try XCTUnwrap(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: evmDescriptor,
                accounts: [wallet]
            )
        )

        XCTAssertEqual(substrateTarget.wallet.metaId, wallet.metaId)
        XCTAssertEqual(substrateTarget.chainId, Chain.polkadot.genesisHash)
        XCTAssertNil(substrateTarget.accountId)
        XCTAssertFalse(substrateTarget.isEthereumBased)
        XCTAssertEqual(substrateTarget.address, substrateDescriptor.address)
        XCTAssertEqual(substrateTarget.ecosystem, .substrate)

        XCTAssertEqual(evmTarget.wallet.metaId, wallet.metaId)
        XCTAssertEqual(evmTarget.chainId, Chain.moonriver.genesisHash)
        XCTAssertNil(evmTarget.accountId)
        XCTAssertTrue(evmTarget.isEthereumBased)
        XCTAssertEqual(evmTarget.address, evmDescriptor.address)
        XCTAssertEqual(evmTarget.ecosystem, .evm)
    }

    func testLegacyExportResolverRejectsUnsafeDescriptors() throws {
        let wallet = Self.wallet()
        let descriptor = try legacyDescriptor(for: .substrate, wallet: wallet)

        XCTAssertNil(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: Self.copy(descriptor, canExportSecrets: false),
                accounts: [wallet]
            )
        )
        XCTAssertNil(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: Self.copy(descriptor, canSignTransactions: true),
                accounts: [wallet]
            )
        )
    }

    func testLegacyExportResolverRejectsTamperedDescriptorIdentity() throws {
        let wallet = Self.wallet()
        let descriptor = try legacyDescriptor(for: .substrate, wallet: wallet)

        XCTAssertNil(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: Self.copy(descriptor, vaultId: "legacy_ios_other_substrate"),
                accounts: [wallet]
            )
        )
        XCTAssertNil(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: Self.copy(descriptor, accountId: "ios-wallet-12345678-other"),
                accounts: [wallet]
            )
        )
        XCTAssertNil(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: Self.copy(descriptor, address: "unavailable:ios:other:substrate"),
                accounts: [wallet]
            )
        )
    }

    func testLegacyExportResolverRejectsUnsupportedEcosystems() {
        let wallet = Self.wallet()

        [UniversalWalletEcosystem.ton, .bitcoin, .solana, .iroha].forEach { ecosystem in
            XCTAssertNil(
                IOSUniversalWalletLegacyExportResolver.resolve(
                    descriptor: Self.legacyVault(ecosystem: ecosystem),
                    accounts: [wallet]
                )
            )
        }
    }

    func testLegacyExportResolverRejectsDescriptorsWithoutRootMaterial() {
        let substrateWallet = Self.wallet(substrateAccountId: Data(), substratePublicKey: Data())
        XCTAssertNil(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: Self.legacyVault(
                    ecosystem: .substrate,
                    address: "unavailable:ios:wallet-12345678:substrate"
                ),
                accounts: [substrateWallet]
            )
        )

        let evmWallet = Self.wallet(ethereumAddress: nil, ethereumPublicKey: nil)
        XCTAssertNil(
            IOSUniversalWalletLegacyExportResolver.resolve(
                descriptor: Self.legacyVault(
                    ecosystem: .evm,
                    address: "unavailable:ios:wallet-12345678:evm"
                ),
                accounts: [evmWallet]
            )
        )
    }

    private func migrationSnapshot(
        schemaVersion: Int = UniversalWalletMigrationSnapshot.schemaVersionValue,
        hasUniversalWallet: Bool = false,
        legacyVaults: [UniversalWalletLegacyVaultDescriptor] = [UniversalWalletMigrationContractTests.legacyVault()],
        cutoffAtMillis: Int64 = 1_710_000_000_000,
        evaluatedAtMillis: Int64 = 1_710_000_000_100
    ) -> UniversalWalletMigrationSnapshot {
        UniversalWalletMigrationSnapshot(
            schemaVersion: schemaVersion,
            platform: .ios,
            hasUniversalWallet: hasUniversalWallet,
            legacyVaults: legacyVaults,
            cutoffAtMillis: cutoffAtMillis,
            evaluatedAtMillis: evaluatedAtMillis
        )
    }

    private func legacyDescriptor(
        for ecosystem: UniversalWalletEcosystem,
        wallet: MetaAccountModel = UniversalWalletMigrationContractTests.wallet()
    ) throws -> UniversalWalletLegacyVaultDescriptor {
        let snapshot = builder.build(accounts: [wallet])

        return try XCTUnwrap(snapshot.legacyVaults.first { $0.ecosystem == ecosystem.rawValue })
    }

    private static func legacyVault() -> UniversalWalletLegacyVaultDescriptor {
        UniversalWalletLegacyVaultDescriptor(
            vaultId: "legacy_12345678",
            accountId: "substrate-legacy",
            ecosystem: .substrate,
            address: "15FKRtF6nX3SE4PaW4LX69XqYHq2oSep9JX5KF4cgN1XkZ4q",
            displayName: "Legacy DOT",
            exportOnlyReason: "pre-cutoff account export",
            discoveredAtMillis: 1_700_000_000_000,
            lastExportedAtMillis: 1_700_000_000_100
        )
    }

    private static func legacyVault(
        ecosystem: UniversalWalletEcosystem,
        address: String? = nil
    ) -> UniversalWalletLegacyVaultDescriptor {
        UniversalWalletLegacyVaultDescriptor(
            vaultId: "legacy_ios_wallet-12345678_\(ecosystem.rawValue)",
            accountId: "ios-wallet-12345678-\(ecosystem.rawValue)",
            ecosystem: ecosystem,
            address: address ?? "unavailable:ios:wallet-12345678:\(ecosystem.rawValue)",
            displayName: "Wallet",
            exportOnlyReason: "pre-cutoff account export",
            discoveredAtMillis: 1_710_000_000_000
        )
    }

    private static func copy(
        _ descriptor: UniversalWalletLegacyVaultDescriptor,
        vaultId: String? = nil,
        accountId: String? = nil,
        ecosystem: String? = nil,
        address: String? = nil,
        canExportSecrets: Bool? = nil,
        canSignTransactions: Bool? = nil
    ) -> UniversalWalletLegacyVaultDescriptor {
        UniversalWalletLegacyVaultDescriptor(
            vaultId: vaultId ?? descriptor.vaultId,
            accountId: accountId ?? descriptor.accountId,
            ecosystem: ecosystem ?? descriptor.ecosystem,
            address: address ?? descriptor.address,
            displayName: descriptor.displayName,
            mode: descriptor.mode,
            exportOnlyReason: descriptor.exportOnlyReason,
            canExportSecrets: canExportSecrets ?? descriptor.canExportSecrets,
            canSignTransactions: canSignTransactions ?? descriptor.canSignTransactions,
            discoveredAtMillis: descriptor.discoveredAtMillis,
            lastExportedAtMillis: descriptor.lastExportedAtMillis
        )
    }

    private static func chainAccount(
        chainId: String,
        publicKey: Data,
        cryptoType: UInt8 = CryptoType.ed25519.rawValue
    ) -> ChainAccountModel {
        ChainAccountModel(
            chainId: chainId,
            accountId: publicKey,
            publicKey: publicKey,
            cryptoType: cryptoType,
            ethereumBased: false
        )
    }

    private static func wallet(
        metaId: String = "wallet-12345678",
        name: String = "Wallet",
        substrateAccountId: Data = Data(repeating: 1, count: 32),
        substratePublicKey: Data = Data(repeating: 2, count: 32),
        ethereumAddress: Data? = Data(repeating: 3, count: 20),
        ethereumPublicKey: Data? = Data(repeating: 4, count: 33),
        chainAccounts: Set<ChainAccountModel> = []
    ) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: CryptoType.ed25519.rawValue,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private enum TestFetchError: Error, Equatable {
        case failed
    }
}
