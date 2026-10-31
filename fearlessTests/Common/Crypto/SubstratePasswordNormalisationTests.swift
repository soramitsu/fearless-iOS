@testable import fearless
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import XCTest

/// The Substrate derivation-path password (`//hard///password`) as every client must read it.
///
/// `docs/substrate-password-vectors.json` is written by the web repository's
/// `scripts/generate-substrate-password-vectors.py` (Python standard library only, no client
/// code). Its `nfkd` accounts salt the mini secret with NFKD("mnemonic" + password), which iOS
/// has always done (IrohaCrypto `SNBIP39SeedCreator`). The `nfc` and `asTyped` accounts are what
/// Fearless web 4.2.x and 3.0.x derived; for non-ASCII passwords they are other accounts.
final class SubstratePasswordNormalisationTests: XCTestCase {
    func testMnemonicImport_derivesTheNfkdAccountForEveryPasswordAndCryptoType() throws {
        for vector in try SubstratePasswordVectors.all() {
            for cryptoType in [CryptoType.sr25519, .ed25519, .ecdsa] {
                let label = "\(vector.id) \(cryptoType)"
                let wallet = try SubstratePasswordVectors.importWallet(vector, cryptoType: cryptoType)
                let expected = try vector.account("nfkd", cryptoType)

                XCTAssertEqual(wallet.substrateAccountId?.toHex(includePrefix: true), expected.accountId, label)
                XCTAssertEqual(wallet.substratePublicKey?.toHex(includePrefix: true), expected.publicKey, label)
                if !vector.rulesAgree {
                    XCTAssertNotEqual(
                        wallet.substrateAccountId?.toHex(includePrefix: true),
                        try vector.account("nfc", cryptoType).accountId,
                        "\(label): the NFC (web 4.2) account must differ, or the vector proves nothing"
                    )
                }
            }
        }
    }

    func testComposedAndDecomposedPasswords_openTheSameAccount() throws {
        let composed = try SubstratePasswordVectors.vector("default24-unicode")
        let decomposed = try SubstratePasswordVectors.vector("default24-unicode-decomposed-input")
        XCTAssertNotEqual(
            Array(composed.derivationPath.unicodeScalars),
            Array(decomposed.derivationPath.unicodeScalars),
            "The two vectors must hold different code points"
        )

        let first = try SubstratePasswordVectors.importWallet(composed, cryptoType: .sr25519)
        let second = try SubstratePasswordVectors.importWallet(decomposed, cryptoType: .sr25519)

        XCTAssertEqual(first.substrateAccountId, second.substrateAccountId)
    }
}

enum SubstratePasswordVectors {
    struct Account {
        let publicKey: String
        let accountId: String
    }

    struct Vector {
        let id: String
        let mnemonic: String
        let derivationPath: String
        let rulesAgree: Bool
        let accounts: [String: [String: Any]]

        func account(_ rule: String, _ cryptoType: CryptoType) throws -> Account {
            let key: String
            switch cryptoType {
            case .sr25519: key = "sr25519"
            case .ed25519: key = "ed25519"
            case .ecdsa: key = "ecdsa"
            }
            let entry = try XCTUnwrap(accounts[rule]?[key] as? [String: String], "\(id) \(rule) \(key)")
            return try Account(
                publicKey: XCTUnwrap(entry["publicKey"]),
                accountId: XCTUnwrap(entry["accountId"])
            )
        }
    }

    static func all() throws -> [Vector] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Crypto
            .deletingLastPathComponent() // Common
            .deletingLastPathComponent() // fearlessTests
            .deletingLastPathComponent()
            .appendingPathComponent("docs/substrate-password-vectors.json")
        let data = try Data(contentsOf: url)
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(document["canonicalRule"] as? String, "nfkd")
        let vectors = try XCTUnwrap(document["vectors"] as? [[String: Any]])
        return try vectors.map { vector in
            try Vector(
                id: XCTUnwrap(vector["id"] as? String),
                mnemonic: XCTUnwrap(vector["mnemonic"] as? String),
                derivationPath: XCTUnwrap(vector["derivationPath"] as? String),
                rulesAgree: XCTUnwrap(vector["rulesAgree"] as? Bool),
                accounts: XCTUnwrap(vector["accounts"] as? [String: [String: Any]])
            )
        }
    }

    static func vector(_ id: String) throws -> Vector {
        try XCTUnwrap(try all().first { $0.id == id }, "vector \(id)")
    }

    /// The import screen's operation, as `AccountImportInteractor` starts it.
    static func importWallet(
        _ vector: Vector,
        cryptoType: CryptoType,
        keystore: KeystoreProtocol = InMemoryKeychain()
    ) throws -> MetaAccountModel {
        let operation = try MetaAccountOperationFactory(keystore: keystore).newMetaAccountOperation(
            request: MetaAccountImportMnemonicRequest(
                mnemonic: IRMnemonicCreator().mnemonic(fromList: vector.mnemonic),
                username: vector.id,
                substrateDerivationPath: vector.derivationPath,
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: cryptoType,
                defaultChainId: nil
            ),
            isBackuped: false
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }
}
