import BigInt
import IrohaCrypto
import SSFCrypto
import SSFModels
import SSFUtils
import XCTest

@testable import SSFKeyPair

final class JsonCreatorTests: XCTestCase {
    var jsonCreator: JsonCreator?
    var keystoreExtractor: KeystoreExtractor?

    override func setUp() {
        super.setUp()

        let jsonCreator = JsonCreatorImpl()
        let keystoreExtractor = KeystoreExtractor()

        self.jsonCreator = jsonCreator
        self.keystoreExtractor = keystoreExtractor
    }

    override func tearDown() {
        super.tearDown()
        jsonCreator = nil
        keystoreExtractor = nil
    }

    func testCreateJson() {
        // Act
        do {
            let result = try jsonCreator?.createJson(
                strength: .entropy128,
                walletName: "wallet",
                password: "password",
                cryptoType: .sr25519,
                derivationPath: "",
                isEthereumBased: false
            )

            // Assert
            XCTAssertNotNil(result)
            XCTAssertNotNil(result?.json)
            XCTAssertEqual(result?.mnemonic.numberOfWords(), 12)
        } catch {
            XCTFail("Create json test failed with error - \(error)")
        }
    }

    func testSubsctrateJson() throws {
        let derivationPaths: [String] = [
            "",
            "//foo//boo",
            "//1231",
        ]

        try performJsonCreatorTest(
            ethereumBased: false,
            cryptoTypes: [.sr25519, .ed25519, .ecdsa],
            derivationPaths: derivationPaths
        )
    }

    func testEthereumBasedJson() throws {
        let derivationPaths: [String] = [
            "",
            "/0",
            "//0",
            "/12//3",
        ]

        try performJsonCreatorTest(
            ethereumBased: true,
            cryptoTypes: [.ecdsa],
            derivationPaths: derivationPaths
        )
    }
}

extension JsonCreatorTests {
    func performJsonCreatorTest(
        ethereumBased: Bool,
        cryptoTypes: [CryptoType],
        derivationPaths: [String]
    ) throws {
        let passwords: [String] = ["", "password"]
        let strengths: [IRMnemonicStrength] = [
            .entropy128,
            .entropy160,
            .entropy192,
            .entropy224,
            .entropy256,
            .entropy288,
            .entropy320,
        ]

        for strength in strengths {
            for password in passwords {
                for cryptoType in cryptoTypes {
                    for derivationPath in derivationPaths {
                        let expectedResult = try jsonCreator?.createJson(
                            strength: strength,
                            walletName: "wallet",
                            password: password,
                            cryptoType: cryptoType,
                            derivationPath: derivationPath,
                            isEthereumBased: ethereumBased
                        )

                        let derivedResult = try jsonCreator?.deriveJson(
                            mnemonicWords: expectedResult?.mnemonic.toString() ?? "",
                            walletName: "wallet",
                            password: password,
                            cryptoType: cryptoType,
                            derivationPath: derivationPath,
                            isEthereumBased: ethereumBased
                        )

                        XCTAssertNotNil(expectedResult)
                        XCTAssertNotNil(derivedResult)

                        let expectedMnemonic = expectedResult?.mnemonic
                        let derivedMnemonic = derivedResult?.mnemonic

                        XCTAssertNotNil(expectedMnemonic)
                        XCTAssertNotNil(derivedMnemonic)

                        let expectedDefinition = try JSONDecoder().decode(
                            KeystoreDefinition.self,
                            from: expectedResult?.json ?? Data()
                        )
                        let derivedDefinition = try JSONDecoder().decode(
                            KeystoreDefinition.self,
                            from: derivedResult?.json ?? Data()
                        )

                        let expectedKeystoreData = try keystoreExtractor?.extractFromDefinition(
                            expectedDefinition,
                            password: password
                        )
                        let derivedKeystoreData = try keystoreExtractor?.extractFromDefinition(
                            derivedDefinition,
                            password: password
                        )

                        XCTAssertNotNil(expectedKeystoreData)
                        XCTAssertNotNil(derivedKeystoreData)

                        XCTAssertEqual(
                            expectedKeystoreData?.publicKeyData.toHex(),
                            derivedKeystoreData?.publicKeyData.toHex()
                        )
                        XCTAssertEqual(
                            expectedKeystoreData?.secretKeyData.toHex(),
                            derivedKeystoreData?.secretKeyData.toHex()
                        )
                        XCTAssertEqual(expectedMnemonic?.toString(), derivedMnemonic?.toString())
                        XCTAssertEqual(expectedMnemonic?.entropy(), derivedMnemonic?.entropy())
                    }
                }
            }
        }
    }
}
