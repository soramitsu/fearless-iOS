import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels
import SSFUtils
import WalletCore
import XCTest
@testable import WalletEngine

final class WalletKeysTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private struct VectorSet<T: Decodable>: Decodable { let vectors: [T] }
    private struct Universal: Decodable {
        struct Expected: Decodable {
            struct Substrate: Decodable { let publicKeyHex, polkadotAddress: String }
            struct EVM: Decodable { let address: String }
            let substrate: Substrate
            let evm: EVM
        }

        let mnemonic: String
        let expected: Expected
    }

    func testCrossPlatform12And24WordVectors() throws {
        let cases = try JSONDecoder().decode(VectorSet<Universal>.self, from: fixture("universal-wallet-v2-vectors"))
        XCTAssertEqual(cases.vectors.count, 2)
        for test in cases.vectors {
            let words = test.mnemonic.components(separatedBy: " ")
            let wallet = try WalletKeys.importSource(.mnemonic(words: words, options: .standard))
            let substrate = try XCTUnwrap(wallet.accounts.first { $0.ecosystem == .substrate })
            let evm = try XCTUnwrap(wallet.accounts.first { $0.ecosystem == .evm })
            XCTAssertEqual(substrate.publicKey.toHex(), test.expected.substrate.publicKeyHex)
            XCTAssertEqual(try WalletKeys.address(substrate, prefix: 0), test.expected.substrate.polkadotAddress)
            XCTAssertEqual(try WalletKeys.address(evm, prefix: nil), test.expected.evm.address)
            XCTAssertNil(substrate.derivationPath)
            XCTAssertEqual(evm.derivationPath, DerivationOptions.defaultEVMPath)
            let entropy = try XCTUnwrap(wallet.secret?.entropy)
            XCTAssertTrue(try IRMnemonicCreator().mnemonic(fromEntropy: entropy).allWords() == words)
        }
    }

    func testRootAndChildDerivationsAgainstIndependentClients() throws {
        let row = try XCTUnwrap(JSONDecoder().decode(
            VectorSet<Universal>.self,
            from: fixture("universal-wallet-v2-vectors")
        ).vectors.first)
        // Independent fixtures from @polkadot/keyring 14.0.3 addFromUri and ethers 6.17.0
        // HDNodeWallet.fromPhrase using import12 from the shared cross-platform fixture.
        let cases: [(WalletCore.CryptoType, String, String)] = [
            (.ed25519, "", "9125f505bdef2cb5825b9931769316d3e2f22150786489a04f39b434ec9fb294"),
            (.ecdsa, "", "035c080d535720870caab8d33acdbc59f4cede44fe599980289a1c01fcec2a4112"),
            (.sr25519, "//hard/soft", "a4ab85b3f6ab6c3166b2cf6def47c3977bf6e8f45fb593d7aaefbcbf25919d67"),
            (.sr25519, "//hard/soft///TREZOR", "fc375d3a994762eb899837fb94edceb62172c8c4efd28a35b051ceca15355502"),
            (.ed25519, "//hard", "2365b08976e7a3932208b25a66ba0482510511f55e5530ea7784ef6d413598f8"),
            (.ecdsa, "//hard", "033446be66445e04bd2424a07bdab2c27b641d5002ce698b04658193928f2f442c")
        ]
        for (type, path, expected) in cases {
            let options = DerivationOptions(
                substrateCryptoType: type,
                substrateDerivationPath: path,
                evmDerivationPath: "m/44'/60'/0'/0/1"
            )
            let wallet = try WalletKeys.importSource(.mnemonic(
                words: row.mnemonic.components(separatedBy: " "),
                options: options
            ))
            XCTAssertEqual(wallet.accounts.first { $0.ecosystem == .substrate }?.publicKey.toHex(), expected)
            let evm = try XCTUnwrap(wallet.accounts.first { $0.ecosystem == .evm })
            XCTAssertEqual(try WalletKeys.address(evm, prefix: nil), "0x6Fac4D18c912343BF86fa7049364Dd4E424Ab9C0")
        }
        let passwordPaths = [DerivationOptions.defaultEVMPath + "///TREZOR", "//44//60//0/0/0///TREZOR"]
        for path in passwordPaths {
            let imported = try WalletKeys.importSource(.mnemonic(
                words: row.mnemonic.components(separatedBy: " "),
                options: DerivationOptions(evmDerivationPath: path)
            ))
            let evm = try XCTUnwrap(imported.accounts.first { $0.ecosystem == .evm })
            XCTAssertEqual(try WalletKeys.address(evm, prefix: nil), "0x9c32F71D4DB8Fb9e1A58B0a80dF79935e7256FA6")
        }
    }

    private struct PasswordVector: Decodable {
        struct Account: Decodable { let publicKey, ss58Polkadot: String }
        struct Rules: Decodable { let nfkd: [String: Account]
            private enum CodingKeys: String, CodingKey { case nfkd }
            init(from decoder: Decoder) throws {
                let row = try decoder.container(keyedBy: CodingKeys.self)
                let accounts = try row.nestedContainer(keyedBy: Keys.self, forKey: .nfkd)
                nfkd = try Dictionary(uniqueKeysWithValues: Keys.allCases.map {
                    try ($0.rawValue, accounts.decode(Account.self, forKey: $0))
                })
            }

            private enum Keys: String, CodingKey, CaseIterable { case sr25519, ed25519, ecdsa }
        }

        let mnemonic, derivationPath: String
        let accounts: Rules
    }

    func testSubstrateJunctionAndPasswordVectorsForAllSchemes() throws {
        let cases = try JSONDecoder().decode(
            VectorSet<PasswordVector>.self,
            from: fixture("substrate-password-vectors")
        )
        XCTAssertEqual(cases.vectors.count, 5)
        for row in cases.vectors {
            for type in WalletCore.CryptoType.allCases {
                let opts = DerivationOptions(substrateCryptoType: type, substrateDerivationPath: row.derivationPath)
                let wallet = try WalletKeys.importSource(.mnemonic(
                    words: row.mnemonic.components(separatedBy: " "),
                    options: opts
                ))
                let account = try XCTUnwrap(wallet.accounts.first { $0.ecosystem == .substrate })
                let expected = try XCTUnwrap(row.accounts.nfkd[type.rawValue])
                XCTAssertEqual(account.publicKey.toHex(includePrefix: true), expected.publicKey)
                XCTAssertEqual(try WalletKeys.address(account, prefix: 0), expected.ss58Polkadot)
            }
        }
    }

    func testRawSeedRFC8032AndEVMPrivateKey() throws {
        let opts = DerivationOptions(substrateCryptoType: .ed25519)
        let wallet = try WalletKeys.importSource(.seed(
            hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
            ecosystem: .substrate,
            options: opts
        ))
        XCTAssertEqual(
            wallet.accounts.first?.publicKey.toHex(),
            "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        )
        let signature = try XCTUnwrap(wallet.secret).sign(Data(), ecosystem: .substrate)
        XCTAssertEqual(
            signature.toHex(),
            "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
                "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
        )
        let evm = try WalletKeys.importSource(.seed(
            hex: String(repeating: "0", count: 63) + "1",
            ecosystem: .evm,
            options: .standard
        ))
        XCTAssertEqual(
            try WalletKeys.address(XCTUnwrap(evm.accounts.first), prefix: nil),
            "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
        )
        XCTAssertThrowsError(try WalletKeys.importSource(.seed(hex: "x1", ecosystem: .evm, options: opts)))
        XCTAssertThrowsError(try WalletKeys.importSource(.seed(
            hex: String(repeating: "0", count: 64),
            ecosystem: .evm,
            options: opts
        )))
    }

    func testFourPolkadotJSBackupsImportExportAndSign() throws {
        struct Backup {
            let file: String
            let password: String
            let ecosystem: Ecosystem
            let type: WalletCore.CryptoType
        }
        let backups = [
            Backup(file: "validSrKeystore", password: "test5", ecosystem: .substrate, type: .sr25519),
            Backup(file: "validEd25519Keystore", password: "test2", ecosystem: .substrate, type: .ed25519),
            Backup(file: "validEcdsaKeystore", password: "test3", ecosystem: .substrate, type: .ecdsa),
            Backup(file: "validEthereumKeystore", password: "123", ecosystem: .evm, type: .ecdsa)
        ]
        for backup in backups {
            let ecosystem = backup.ecosystem, type = backup.type
            let data = try fixture(backup.file)
            let source = try WalletKeys.importSource(.json(data: data, password: backup.password))
            let secret = try XCTUnwrap(source.secret)
            XCTAssertEqual(try secret.accounts(), source.accounts)
            let account = try XCTUnwrap(source.accounts.first)
            XCTAssertEqual(account.cryptoType, type)
            XCTAssertEqual(account.ecosystem, ecosystem)
            let exported = try secret.exportJSON(ecosystem: ecosystem, name: "Test wallet", password: "Round-trip-2026")
            let restored = try WalletKeys.importSource(.json(data: exported, password: "Round-trip-2026"))
            XCTAssertEqual(restored.accounts, source.accounts)
            let message = Data("Fearless Wallet signature verification".utf8)
            let bytes = try XCTUnwrap(restored.secret).sign(message, ecosystem: ecosystem)
            switch type {
            case .sr25519:
                XCTAssertTrue(try SNSignatureVerifier().verify(
                    SNSignature(rawData: bytes),
                    forOriginalData: message,
                    using: SNPublicKey(rawData: account.publicKey)
                ))
            case .ed25519:
                XCTAssertTrue(try EDSignatureVerifier().verify(
                    EDSignature(rawData: bytes),
                    forOriginalData: message,
                    usingPublicKey: EDPublicKey(rawData: account.publicKey)
                ))
            case .ecdsa:
                let encoded = try KeystoreExtractor().extractFromDefinition(
                    JSONDecoder().decode(
                        KeystoreDefinition.self,
                        from: exported
                    ),
                    password: "Round-trip-2026"
                )
                let digest = try ecosystem == .evm ? message.keccak256() : message.blake2b32()
                XCTAssertTrue(try SECSignatureVerifier().verify(
                    SECSignature(rawData: bytes),
                    forOriginalData: digest,
                    usingPublicKey: SECPublicKey(rawData: encoded.publicKeyData)
                ))
            }
        }
    }

    func testBackupRejectsWrongPasswordAndModifiedAddress() throws {
        let data = try fixture("validSrKeystore")
        XCTAssertThrowsError(try WalletKeys.importSource(.json(data: data, password: "incorrect"))) {
            XCTAssertEqual($0 as? WalletError, .wrongJSONPassword)
        }
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)
        let altered = KeystoreDefinition(
            address: "0x" + String(repeating: "00", count: 32),
            encoded: definition.encoded,
            encoding: definition.encoding,
            meta: definition.meta
        )
        XCTAssertThrowsError(try WalletKeys.importSource(.json(data: JSONEncoder().encode(altered), password: "test5")))
    }

    func testSr25519BackupRejectsMismatchedPairAndInvalidScalar() throws {
        let original = try JSONDecoder().decode(KeystoreDefinition.self, from: fixture("validSrKeystore"))
        let extracted = try KeystoreExtractor().extractFromDefinition(original, password: "test5")
        let secret = try SNPrivateKey(rawData: extracted.secretKeyData).toEd25519Data()
        let wrong = try SNKeyFactory().createKeypair(fromSeed: Data((0 ..< 32).map(UInt8.init))).publicKey().rawData()
        for (expanded, publicKey) in [(secret, wrong), (Data(repeating: 255, count: 64), extracted.publicKeyData),
                                      (Data(secret.prefix(31)), extracted.publicKeyData), (
                                          secret,
                                          Data(wrong.dropFirst())
                                      )] {
            let pkcs8 = KeystoreConstants.pkcs8Header + expanded + KeystoreConstants.pkcs8Divider + publicKey
            let json = KeystoreDefinition(
                address: nil,
                encoded: pkcs8.base64EncodedString(),
                encoding:
                KeystoreEncoding(content: ["pkcs8", "sr25519"], type: [], version: "3"),
                meta: nil
            )
            XCTAssertThrowsError(try WalletKeys.importSource(.json(data: JSONEncoder().encode(json), password: "")))
        }
    }

    func testWatchOnlyAndRecipientValidation() throws {
        let dot = try XCTUnwrap(Catalog.networks.first { $0.name == "Polkadot" })
        let kusama = try XCTUnwrap(Catalog.networks.first { $0.name == "Kusama" })
        let eth = try XCTUnwrap(Catalog.networks.first { $0.evmID == 1 })
        let polkadot = "13KVd4f2a4S5pLp4gTTFezyXdPWx27vQ9vS6xBXJ9yWVd7xo"
        let evm = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
        let wallet = try WalletKeys.importSource(.watchOnly(substrateAddress: polkadot, evmAddress: evm))
        XCTAssertEqual(wallet.origin, .watchOnly)
        XCTAssertNil(wallet.secret)
        XCTAssertEqual(wallet.accounts.count, 2)
        XCTAssertEqual(WalletKeys.validate("", on: dot), .empty)
        XCTAssertEqual(WalletKeys.validate(polkadot, on: dot), .valid(normalized: polkadot))
        guard case .wrongNetwork = WalletKeys.validate(polkadot, on: kusama)
        else { return XCTFail("Expected wrong network") }
        guard case .invalid = WalletKeys.validate(String(polkadot.dropLast()) + "1", on: dot)
        else { return XCTFail("Expected checksum error") }
        XCTAssertEqual(WalletKeys.validate(evm.lowercased(), on: eth), .valid(normalized: evm))
        guard case .invalid = WalletKeys.validate(evm.replacingOccurrences(of: "Ef", with: "EF"), on: eth) else {
            return XCTFail("Expected case checksum error")
        }
        XCTAssertThrowsError(try WalletKeys.importSource(.watchOnly(substrateAddress: nil, evmAddress: nil)))
    }
}
