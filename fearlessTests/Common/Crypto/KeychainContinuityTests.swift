// One source-bound historical replay fixture covers all six named invariants.
// swiftlint:disable file_length
import CoreData
import CryptoKit
@testable import fearless
import IrohaCrypto
import RobinHood
import Security
import SoraKeystore
import SSFModels
import SSFUtils
import XCTest

private struct HistoricalKeychainSnapshot: Decodable {
    struct Wallet: Decodable {
        let fixture, metaId, name: String
        let substratePublicKey, substrateAccountId: String?
        let tonPublicKey, tonAddress, tonSerializedAddress, tonContractVersion, tonPhrase: String?
        let ethereumPublicKey, ethereumAddress, mnemonic: String?
        let cryptoType: UInt8?
        let substrateDerivationPath, ethereumDerivationPath: String?
        let substrateAddresses: [String: String]?
        let chainAccounts: [Child]?
        let originalRootSeeds: [String: String]?
        let rootSeedTags: [String: String]?
        let order: UInt32
        let isSelected: Bool
    }

    struct Child: Decodable {
        let fixture, importKind, chainId, publicKey, accountId, address, derivationPath: String
        let expectedExportSeed, exportCaptureTag: String
        let mnemonic: String?
        let cryptoType: UInt8
        let addressPrefix: UInt16
        let ethereumBased: Bool
    }

    struct Secret: Decodable { let tag, hex, accessible, accessGroup: String }
    let release, appRevision, publicPin, bundleId: String
    let profile: String?
    let biometryEnabled: Bool
    let wallets: [Wallet]
    let keychain: [Secret]
}

/// T2 replay over the pinned historical writer’s store and real simulator Keychain.
final class KeychainContinuityTests: XCTestCase {
    private var snapshot: HistoricalKeychainSnapshot!
    private var originalStore: URL!
    private var scratch: URL!
    private let keychain = Keychain()
    private var appBundle: Bundle {
        Bundle(for: UserDataStorageFacade.self)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = docs.appendingPathComponent("historical-state.json")
        if !FileManager.default.fileExists(atPath: path.path) {
            if ProcessInfo.processInfo.environment["FEARLESS_REQUIRE_HISTORICAL_KEYCHAIN"] == "1" {
                XCTFail("Required old-writer fixture missing; G5 cannot pass")
                throw CocoaError(.fileNoSuchFile)
            }
            throw XCTSkip("Requires scripts/upgrade-fixtures/ios/HistoricalWriter; missing fixture is not G5 coverage")
        }
        snapshot = try JSONDecoder().decode(HistoricalKeychainSnapshot.self, from: Data(contentsOf: path))
        XCTAssertEqual(snapshot.release, "4.0.4")
        XCTAssertEqual(snapshot.appRevision, "195b0230743fa3c5fb74fbf05f4e4ee38b2d0bcf")
        XCTAssertEqual(snapshot.bundleId, Bundle.main.bundleIdentifier)
        assertHistoricalInventory()
        originalStore = docs.appendingPathComponent("CoreData/UserDataModel.sqlite")
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoricalKeychain-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch {
            try FileManager.default.removeItem(at: scratch)
        }
        try super.tearDownWithError()
    }

    func testU1HistoricalMapperWalletSetOrderAndSelectionSurvive() throws {
        let wallets = try migratedWallets()
        XCTAssertEqual(wallets.map(\.info.metaId), snapshot.wallets.map(\.metaId))
        XCTAssertEqual(wallets.map(\.info.name), snapshot.wallets.map(\.name))
        XCTAssertEqual(wallets.map(\.order), snapshot.wallets.map(\.order))
        XCTAssertEqual(wallets.map(\.isSelected), snapshot.wallets.map(\.isSelected))
        XCTAssertEqual(wallets.filter(\.isSelected).count, 1)
        XCTAssertEqual(wallets.last?.isSelected, true)
        for wallet in wallets.map(\.info) {
            XCTAssertEqual(wallet.chainAccounts.count, try expected(wallet).chainAccounts?.count ?? 0)
            for child in try expected(wallet).chainAccounts ?? [] {
                let stored = try XCTUnwrap(wallet.chainAccounts.first { $0.chainId == child.chainId })
                XCTAssertEqual(stored.accountId, try bytes(child.accountId))
                XCTAssertEqual(stored.publicKey, try bytes(child.publicKey))
                XCTAssertEqual(stored.cryptoType, child.cryptoType)
                XCTAssertEqual(stored.ethereumBased, child.ethereumBased)
            }
        }
    }

    func testU2EveryHistoricalPublicIdentityAndAddressSurvives() throws {
        for wallet in try migratedWallets().map(\.info) {
            let old = try expected(wallet)
            if old.tonPublicKey != nil {
                try assertTonIdentity(wallet: wallet, old: old)
                continue
            }
            XCTAssertEqual(wallet.substrateCryptoType, old.cryptoType ?? CryptoType.sr25519.rawValue)
            XCTAssertEqual(wallet.substratePublicKey, try bytes(XCTUnwrap(old.substratePublicKey)))
            XCTAssertEqual(wallet.substrateAccountId, try bytes(XCTUnwrap(old.substrateAccountId)))
            XCTAssertEqual(wallet.ethereumPublicKey, try old.ethereumPublicKey.map(bytes))
            XCTAssertEqual(wallet.ethereumAddress, try old.ethereumAddress.map(bytes))
            try assertRootAddresses(wallet: wallet, old: old)
            for child in old.chainAccounts ?? [] {
                let info = try childAccount(wallet, child: child)
                XCTAssertTrue(info.account.isChainAccount)
                XCTAssertEqual(info.account.publicKey, try bytes(child.publicKey))
                XCTAssertEqual(info.account.accountId, try bytes(child.accountId))
                XCTAssertEqual(info.account.cryptoType.rawValue, child.cryptoType)
                XCTAssertEqual(info.account.isEthereumBased, child.ethereumBased)
                let address = try info.account.accountId.toAddress(
                    using: child.ethereumBased ? .sfEthereum : .sfSubstrate(child.addressPrefix)
                )
                XCTAssertEqual(address.lowercased(), child.address.lowercased())
            }
            if let address = old.ethereumAddress {
                XCTAssertEqual(try account(wallet, ethereum: true).account.accountId, try bytes(address))
            } else {
                let chain = ChainAccountRecordsFixture.chain(id: "historical-missing-ethereum", ethereumBased: true)
                XCTAssertNil(wallet.fetch(for: chain.accountRequest()), "Seed-only import must not fabricate Ethereum")
            }
        }
    }

    func testU3ProductionSigningVerifiesEveryHistoricalAccount() throws {
        let cohort = snapshot.profile == "ton-typed-v1" ? "IC-07"
            : snapshot.profile == "per-chain-v1" ? "IC-05"
            : snapshot.profile == "json-only-v1" ? "IC-04"
            : snapshot.profile == "raw-seeds-v1" ? "IC-03"
            : snapshot.profile == "mnemonic-curves-paths-v1" ? "IC-02+GW-M5" : "IC-01"
        let message = Data("fearless-upgrade-matrix-v1|ios|\(cohort)".utf8)
        for wallet in try migratedWallets().map(\.info) {
            if try expected(wallet).tonPublicKey != nil {
                try assertTonSignature(wallet: wallet, message: message)
                continue
            }
            let rootInfos = try ([false] + (wallet.ethereumAddress == nil ? [] : [true]))
                .map { try account(wallet, ethereum: $0) }
            let childInfos = try (expected(wallet).chainAccounts ?? []).map { try childAccount(wallet, child: $0) }
            for info in rootInfos + childInfos {
                let ethereum = info.account.isEthereumBased
                let signature = try SigningWrapper(
                    keystore: keychain,
                    metaId: wallet.metaId,
                    accountResponse: info.account
                ).sign(message)
                if ethereum || info.account.cryptoType == .ecdsa {
                    let digest = try ethereum ? message.keccak256() : message.blake2b32()
                    XCTAssertTrue(try SECSignatureVerifier().verify(
                        signature,
                        forOriginalData: digest,
                        usingPublicKey: SECPublicKey(rawData: info.account.publicKey)
                    ))
                } else if info.account.cryptoType == .ed25519 {
                    XCTAssertTrue(try EDSignatureVerifier().verify(
                        signature,
                        forOriginalData: message,
                        usingPublicKey: EDPublicKey(rawData: info.account.publicKey)
                    ))
                } else {
                    XCTAssertTrue(Sr25519SpecVerifier.verify(
                        signature: signature.rawData(),
                        message: message,
                        publicKey: info.account.publicKey
                    ))
                }
            }
        }
        try assertSecretsUnchanged()
    }

    func testU4MnemonicSeedAndDecryptedJsonExportPreserveHistoricalBytes() throws {
        let mnemonicReader = VerifiedMnemonicExportReader(keystore: keychain)
        let seedReader = VerifiedSeedExportReader(keystore: keychain)
        for wallet in try migratedWallets().map(\.info) {
            let old = try expected(wallet)
            if old.tonPublicKey != nil {
                do {
                    try assertTonPhrase(wallet: wallet, old: old)
                } catch {
                    XCTFail("Exact historical TON phrase export failed for \(old.fixture): \(error)")
                }
                continue
            }
            for ethereum in [false] + (wallet.ethereumAddress == nil ? [] : [true]) {
                let info = try account(wallet, ethereum: ethereum)
                let expectedPath = ethereum ? old.ethereumDerivationPath ?? "//44//60//0/0/0"
                    : old.substrateDerivationPath ?? ""
                try assertPhraseAvailability(
                    reader: mnemonicReader, wallet: wallet, old: old, info: info, expectedPath: expectedPath
                )
                try assertSeedAvailability(
                    reader: seedReader, wallet: wallet, info: info, ethereum: ethereum, expectedPath: expectedPath
                )
                let address = try info.account.accountId.toAddress(using: ethereum ? .sfEthereum : .sfSubstrate(0))
                let json = try KeystoreExportWrapper(keystore: keychain).export(
                    chainAccount: info.account,
                    password: "Public-G5-export-password",
                    address: address,
                    metaId: wallet.metaId,
                    accountId: nil,
                    genesisHash: nil
                )
                let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: json)
                let decoded = try KeystoreExtractor().extractFromDefinition(
                    definition,
                    password: "Public-G5-export-password"
                )
                let secretTag = ethereum ? fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
                    : fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
                XCTAssertEqual(decoded.secretKeyData, try oldSecret(secretTag))
                XCTAssertEqual(decoded.publicKeyData, info.account.publicKey)
                XCTAssertEqual(decoded.address, address)
            }
            try assertChildExports(wallet: wallet, old: old)
        }
        try assertSecretsUnchanged()
    }

    func testU5AllRealKeychainValuesAndAccessProtectionSurviveRepeatedMigration() throws {
        let originalBytes = try Data(contentsOf: originalStore)
        _ = try migratedWallets(repeatMigration: true)
        try assertSecretsUnchanged()
        XCTAssertEqual(try Data(contentsOf: originalStore), originalBytes, "Untouched historical store is evidence")
    }

    @MainActor
    func testU6OriginalPinAuthenticatesAndBiometricPreferenceIsRetained() throws {
        XCTAssertTrue(snapshot.biometryEnabled)
        XCTAssertEqual(SettingsManager.shared.biometryEnabled, snapshot.biometryEnabled)
        let output = AuthOutput()
        let auth = LocalAuthInteractor(
            secretManager: KeychainManager.shared,
            settingsManager: SettingsManager.shared,
            biometryAuth: NoDeviceBiometry(),
            locale: Locale(identifier: "en")
        )
        auth.startAuth(with: output)
        let rejected = expectation(description: "wrong PIN rejected")
        output.wrong = { rejected.fulfill() }
        auth.process(pin: "000000")
        wait(for: [rejected], timeout: 5)
        XCTAssertEqual(auth.state, .waitingPincode)
        let accepted = expectation(description: "same historical PIN accepted")
        output.completed = { accepted.fulfill() }
        auth.process(pin: snapshot.publicPin)
        wait(for: [accepted], timeout: 5)
        XCTAssertEqual(auth.state, .completed)
        XCTAssertEqual(SettingsManager.shared.biometryEnabled, true)
        try assertSecretsUnchanged()
    }
}

private extension KeychainContinuityTests {
    func assertHistoricalInventory() {
        let roots = ["GW-M1", "GW-M2"]
        let profile = snapshot.profile ?? "mnemonic-roots-v1"
        if profile == "ton-typed-v1" {
            XCTAssertEqual(snapshot.wallets.map(\.fixture), ["GW-T1"] + "abcdef".map { "GW-T2" + String($0) })
            XCTAssertEqual(snapshot.keychain.count, 16)
            XCTAssertEqual(snapshot.publicPin, "135790")
            XCTAssertTrue(snapshot.keychain.contains { $0.tag.isEmpty })
        } else if profile == "per-chain-v1" {
            XCTAssertEqual(snapshot.wallets.map(\.fixture), ["GW-M1-chain"])
            XCTAssertEqual(snapshot.keychain.count, 14)
            XCTAssertEqual(snapshot.publicPin, "135790")
            XCTAssertEqual(snapshot.wallets.first?.chainAccounts?.map(\.fixture), [
                "GW-M2-kusama", "GW-S1-westend", "GW-J1-rococo", "GW-M2-moonriver"
            ])
        } else if profile == "json-only-v1" {
            XCTAssertEqual(snapshot.wallets.map(\.fixture), ["GW-J1-sr25519", "GW-J1-ed25519", "GW-J1-ecdsa"])
            XCTAssertEqual(snapshot.keychain.count, 4)
            XCTAssertTrue(snapshot.wallets.allSatisfy { $0.mnemonic == nil && $0.ethereumAddress == nil })
        } else if profile == "raw-seeds-v1" {
            XCTAssertEqual(snapshot.wallets.map(\.fixture), ["GW-S1-sr25519", "GW-S1-ed25519", "GW-S1-with-GW-S2"])
            XCTAssertEqual(snapshot.keychain.count, 9)
            XCTAssertTrue(snapshot.wallets.allSatisfy { $0.mnemonic == nil })
        } else if profile == "mnemonic-curves-paths-v1" {
            XCTAssertEqual(snapshot.wallets.map(\.fixture), roots + [
                "GW-M4-sr25519", "GW-M4-ed25519", "GW-M4-ecdsa", "GW-M5-hard-soft", "GW-M5-soft"
            ])
            XCTAssertEqual(snapshot.keychain.count, 48)
        } else {
            XCTAssertEqual(profile, "mnemonic-roots-v1", "Unknown historical fixture profile")
            XCTAssertEqual(snapshot.wallets.map(\.fixture), roots)
            XCTAssertEqual(snapshot.keychain.count, 13)
        }
    }

    func assertRootAddresses(wallet: MetaAccountModel, old: HistoricalKeychainSnapshot.Wallet) throws {
        let golden: [String: [String]] = [
            "GW-M1": [
                "13KVd4f2a4S5pLp4gTTFezyXdPWx27vQ9vS6xBXJ9yWVd7xo",
                "Etp93jqLeBY8TczVXDJQoWNvMoY8VBSXoYNBYou5ghUBeC1",
                "5EPCUjPxiHAcNooYipQFWr9NmmXJKpNG5RhcntXwbtUySrgH"
            ],
            "GW-M2": [
                "13DyfGHEWo6GF98AxoBbovBHy82rrr4H3LrWaxggtEpgku8o",
                "EoJBFN3HNqiZFw6mrweZii9G6KSyDKKRDxmpKyHox1fKcFE",
                "5EHgWw2Af1pnoc7f1A8bfmM97W3DAYW8xr82RfhLL9oAabAe"
            ]
        ]
        for (index, prefix) in [UInt16(0), 2, 42].enumerated() {
            let chain = ChainAccountRecordsFixture.chain(
                id: ChainAccountRecordsFixture.polkadotChainId,
                prefix: prefix
            )
            let response = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
            XCTAssertEqual(response.accountId, try bytes(XCTUnwrap(old.substrateAccountId)))
            XCTAssertEqual(
                try response.accountId.toAddress(using: .sfSubstrate(prefix)),
                try XCTUnwrap(old.substrateAddresses?[String(prefix)] ?? golden[old.fixture]?[index])
            )
        }
    }

    func assertSeedAvailability(
        reader: VerifiedSeedExportReader,
        wallet: MetaAccountModel,
        info: ChainAccountInfo,
        ethereum: Bool,
        expectedPath: String
    ) throws {
        let seedTag = ethereum ? fearless.KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId)
            : fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        if snapshot.profile == "json-only-v1" {
            XCTAssertNil(try keychain.loadIfKeyExists(seedTag), "Historical JSON import stored no raw seed")
            if info.account.cryptoType == .sr25519 {
                XCTAssertThrowsError(try reader.fetchSeed(
                    metaId: wallet.metaId, accountId: nil, publicKey: info.account.publicKey,
                    cryptoType: info.account.cryptoType, ethereumBased: ethereum
                )) { error in
                    XCTAssertEqual(error as? VerifiedSeedExportError, .missingSeed)
                }
                return
            }
        }
        let seed = try reader.fetchSeed(
            metaId: wallet.metaId, accountId: nil, publicKey: info.account.publicKey,
            cryptoType: info.account.cryptoType, ethereumBased: ethereum
        )
        let expectedTag = snapshot.profile == "json-only-v1"
            ? fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId) : seedTag
        if let original = try expected(wallet).originalRootSeeds?[ethereum ? "ethereum" : "substrate"] {
            XCTAssertEqual(seed.seed, try bytes(original), "Recover the exact old root seed, not the overwritten tag")
            XCTAssertNotEqual(try oldSecret(seedTag), try bytes(original), "The historical overwrite is retained")
        } else {
            XCTAssertEqual(seed.seed, try oldSecret(expectedTag))
        }
        if ethereum || snapshot.profile == "json-only-v1" {
            XCTAssertNil(seed.derivationPath, "Export is the already-derived private key")
        } else {
            XCTAssertEqual(seed.derivationPath ?? "", expectedPath)
        }
    }

    func assertPhraseAvailability(
        reader: VerifiedMnemonicExportReader,
        wallet: MetaAccountModel,
        old: HistoricalKeychainSnapshot.Wallet,
        info: ChainAccountInfo,
        expectedPath: String
    ) throws {
        if let phrase = old.mnemonic {
            let mnemonic = try reader.fetch(wallet: wallet, info: info)
            XCTAssertEqual(mnemonic.mnemonic.allWords().joined(separator: " "), phrase)
            XCTAssertEqual(mnemonic.derivationPath ?? "", expectedPath)
        } else {
            XCTAssertThrowsError(try reader.fetch(wallet: wallet, info: info)) { error in
                XCTAssertEqual(error as? UniversalWalletRootRecoveryError, .phraseDoesNotMatchWallet)
            }
            let entropyTag = fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            XCTAssertNil(try keychain.loadIfKeyExists(entropyTag))
            XCTAssertNil(reader.backupProof(wallet: wallet, exports: []))
        }
    }

    func tonAccount(_ wallet: MetaAccountModel) throws -> ChainAccountInfo {
        let chain = ChainAccountRecordsFixture.chain(id: TonChainSelection.mainnetChainId)
        return try ChainAccountInfo(chain: chain, account: XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
    }

    func assertTonIdentity(wallet: MetaAccountModel, old: HistoricalKeychainSnapshot.Wallet) throws {
        let legacy = try XCTUnwrap(wallet.legacyTonAccount)
        XCTAssertEqual(legacy.publicKey, try bytes(XCTUnwrap(old.tonPublicKey)))
        XCTAssertEqual(legacy.serializedAddress, try bytes(XCTUnwrap(old.tonSerializedAddress)))
        XCTAssertEqual(legacy.contractVersion, old.tonContractVersion)
        XCTAssertEqual(legacy.address, old.tonAddress)
        XCTAssertNil(wallet.substratePublicKey)
        XCTAssertNil(wallet.substrateAccountId)
        XCTAssertNil(wallet.ethereumPublicKey)
        XCTAssertNil(wallet.ethereumAddress)
        let info = try tonAccount(wallet)
        XCTAssertEqual(info.account.publicKey, legacy.publicKey)
        XCTAssertEqual(info.account.accountId, legacy.serializedAddress)
        XCTAssertEqual(info.account.cryptoType, .ed25519)
        XCTAssertFalse(info.account.isChainAccount)
    }

    func assertTonSignature(wallet: MetaAccountModel, message: Data) throws {
        let legacy = try XCTUnwrap(wallet.legacyTonAccount)
        let credentials = try legacy.signingCredentials(keystore: keychain, metaId: wallet.metaId)
        let secret = try XCTUnwrap(credentials.legacyNativePrivateKey)
        XCTAssertEqual(secret, try oldSecret(fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)))
        // Production credential lookup/identity validation plus local native signing primitive; no transaction.
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: secret.prefix(32))
        let signature = try key.signature(for: message)
        let publicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: bytes(XCTUnwrap(expected(wallet).tonPublicKey))
        )
        XCTAssertTrue(publicKey.isValidSignature(signature, for: message))
    }

    func assertTonPhrase(wallet: MetaAccountModel, old: HistoricalKeychainSnapshot.Wallet) throws {
        let phrase = try XCTUnwrap(old.tonPhrase)
        let stored = try oldSecret(fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        XCTAssertEqual(stored, Data(phrase.utf8))
        let options = AvailableExportOptionsProvider(keystore: keychain)
            .getAvailableExportOptions(for: wallet, accountId: nil)
        XCTAssertEqual(options, [.mnemonic], "Native TON offers its verified exact phrase, not BIP39/JSON exports")
        let reader = VerifiedMnemonicExportReader(keystore: keychain)
        let exported = try reader.fetch(wallet: wallet, info: tonAccount(wallet))
        XCTAssertEqual(exported.mnemonic.toString(), phrase)
        XCTAssertEqual(exported.mnemonic.entropy(), stored)
        XCTAssertEqual(exported.mnemonic.allWords(), phrase.components(separatedBy: " "))
        XCTAssertNil(exported.derivationPath)
        XCTAssertNotNil(reader.backupProof(wallet: wallet, exports: [exported]))
        XCTAssertNil(try keychain.loadIfKeyExists(wallet.metaId + "-tonSeed"))
    }

    func childAccount(_ wallet: MetaAccountModel, child: HistoricalKeychainSnapshot.Child) throws -> ChainAccountInfo {
        let chain = ChainAccountRecordsFixture.chain(
            id: child.chainId, prefix: child.addressPrefix, ethereumBased: child.ethereumBased
        )
        return try ChainAccountInfo(chain: chain, account: XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
    }

    func assertChildExports(wallet: MetaAccountModel, old: HistoricalKeychainSnapshot.Wallet) throws {
        let reader = VerifiedMnemonicExportReader(keystore: keychain)
        var phrases: [VerifiedMnemonicExport] = []
        for child in old.chainAccounts ?? [] {
            let info = try childAccount(wallet, child: child)
            let accountId = info.account.accountId
            if let phrase = child.mnemonic {
                let exported = try reader.fetch(wallet: wallet, info: info)
                XCTAssertEqual(exported.mnemonic.allWords().joined(separator: " "), phrase)
                XCTAssertEqual(exported.derivationPath ?? "", child.derivationPath)
                phrases.append(exported)
            } else {
                XCTAssertThrowsError(try reader.fetch(wallet: wallet, info: info)) { error in
                    XCTAssertEqual(error as? UniversalWalletRootRecoveryError, .phraseDoesNotMatchWallet)
                }
                XCTAssertNil(try keychain.loadIfKeyExists(
                    fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId)
                ))
            }
            let seed = try VerifiedSeedExportReader(keystore: keychain).fetchSeed(
                metaId: wallet.metaId, accountId: accountId, publicKey: info.account.publicKey,
                cryptoType: info.account.cryptoType, ethereumBased: child.ethereumBased
            )
            XCTAssertEqual(seed.seed, try bytes(child.expectedExportSeed), child.fixture)
            XCTAssertEqual(seed.derivationPath ?? "", child.ethereumBased ? "" : child.derivationPath)
            // Historical per-chain imports did not create an account-scoped seed tag.
            let seedTag = child.ethereumBased
                ? fearless.KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId, accountId: accountId)
                : fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: accountId)
            XCTAssertNil(try keychain.loadIfKeyExists(seedTag))
            try assertChildJson(wallet: wallet, child: child, info: info)
        }
        if !(old.chainAccounts ?? []).isEmpty {
            // Neither the root phrase alone nor both mnemonic children cover this mixed inventory.
            phrases += try [false, true].map { try reader.fetch(wallet: wallet, info: account(wallet, ethereum: $0)) }
            XCTAssertNil(reader.backupProof(wallet: wallet, exports: phrases))
        }
    }

    func assertChildJson(
        wallet: MetaAccountModel, child: HistoricalKeychainSnapshot.Child, info: ChainAccountInfo
    ) throws {
        let json = try KeystoreExportWrapper(keystore: keychain).export(
            chainAccount: info.account, password: "Public-G5-export-password", address: child.address,
            metaId: wallet.metaId, accountId: info.account.accountId, genesisHash: child.chainId
        )
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: json)
        let decoded = try KeystoreExtractor().extractFromDefinition(definition, password: "Public-G5-export-password")
        let tag = child.ethereumBased
            ? fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: info.account.accountId)
            : fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: info.account.accountId)
        XCTAssertEqual(decoded.secretKeyData, try oldSecret(tag))
        XCTAssertEqual(decoded.publicKeyData, info.account.publicKey)
        XCTAssertEqual(decoded.address, child.address)
    }

    func bytes(_ hex: String) throws -> Data {
        try Data(hexStringSSF: hex)
    }

    func expected(_ wallet: MetaAccountModel) throws -> HistoricalKeychainSnapshot.Wallet {
        try XCTUnwrap(snapshot.wallets.first { $0.metaId == wallet.metaId })
    }

    func oldSecret(_ tag: String) throws -> Data {
        try bytes(XCTUnwrap(snapshot.keychain.first { $0.tag == tag }).hex)
    }

    func assertSecretsUnchanged() throws {
        for old in snapshot.keychain {
            XCTAssertEqual(try keychain.fetchKey(for: old.tag), try bytes(old.hex), old.tag)
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: Data(old.tag.utf8),
                kSecReturnAttributes as String: true
            ]
            var result: CFTypeRef?
            XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
            let attributes = try XCTUnwrap(result as? [String: Any])
            XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, old.accessible)
            XCTAssertEqual(attributes[kSecAttrAccessGroup as String] as? String, old.accessGroup)
            XCTAssertEqual(old.accessible, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        }
    }

    func account(_ wallet: MetaAccountModel, ethereum: Bool) throws -> ChainAccountInfo {
        let chain = ChainAccountRecordsFixture.chain(
            id: ethereum ? ChainAccountRecordsFixture.moonbeamChainId
                : ChainAccountRecordsFixture.polkadotChainId,
            ethereumBased: ethereum
        )
        return try ChainAccountInfo(chain: chain, account: XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
    }

    func migratedWallets(repeatMigration: Bool = false) throws -> [fearless.ManagedMetaAccountModel] {
        let store = scratch.appendingPathComponent("UserDataModel.sqlite")
        try FileManager.default.copyItem(at: originalStore, to: store)
        let migrator = UserStorageMigrator(
            targetVersion: .version14,
            storeURL: store,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: SettingsManager.shared,
            fileManager: .default,
            modelBundle: appBundle
        )
        XCTAssertTrue(try migrator.performMigration())
        if repeatMigration {
            XCTAssertFalse(try migrator.performMigration())
        }
        let url = try XCTUnwrap(UserStorageVersion.version14.modelURL(
            in: appBundle,
            legacyModelDirectory: UserStorageParams.modelDirectory
        ))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
        let classes: [String: NSManagedObject.Type] = [
            "CDAccountInfo": CDAccountInfo.self,
            "CDAssetVisibility": CDAssetVisibility.self,
            "CDChainAccount": CDChainAccount.self,
            "CDChainSettings": CDChainSettings.self,
            "CDCurrency": CDCurrency.self,
            "CDCustomChainNode": CDCustomChainNode.self,
            "CDMetaAccount": CDMetaAccount.self
        ]
        for entity in model.entities {
            if let type = classes[entity.name ?? ""] {
                entity.managedObjectClassName = NSStringFromClass(type)
            }
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let persistentStore = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: store,
            options: nil
        )
        defer { try? coordinator.remove(persistentStore) }
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        return try context.fetch(request).map { try ManagedMetaAccountMapper().transform(entity: $0) }
    }

    final class AuthOutput: LocalAuthInteractorOutputProtocol {
        var wrong: (() -> Void)?
        var completed: (() -> Void)?
        func didEnterWrongPincode() {
            wrong?()
        }

        func didCompleteAuth() {
            completed?()
        }

        func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}
        func didUnexpectedFail() {
            XCTFail("Historical PIN load failed")
        }
    }

    final class NoDeviceBiometry: BiometryAuthProtocol {
        var availableBiometryType: AvailableBiometryType {
            .none
        }

        func authenticate(
            localizedReason _: String,
            completionQueue _: DispatchQueue,
            completionBlock _: @escaping (Bool) -> Void
        ) {
            XCTFail("This test must use the persisted PIN, not a simulated biometric success")
        }

        func cancelAuthentication() {}
    }
}

// swiftlint:enable file_length
