import BigInt
import IrohaCrypto
import MocksBasket
import SSFCrypto
import SSFModels
import SSFUtils
import XCTest

@testable import SSFKeyPair

final class SeedCreatorTests: XCTestCase {
    var seedCreator: SeedCreator?

    override func setUp() {
        super.setUp()
        let seedCreator = SeedCreatorImpl()
        self.seedCreator = seedCreator
    }

    override func tearDown() {
        super.tearDown()
        seedCreator = nil
    }

    func testGeneratedSeedMatchesDerived() throws {
        try performSeedCreatorTest(ethereumBased: false, cryptoTypes: [.sr25519, .ed25519, .ecdsa])
    }

    func testGeneratedBIP32SeedMatchesDerived() throws {
        try performSeedCreatorTest(ethereumBased: true, cryptoTypes: [.ecdsa])
    }

    func testCreateSeed() {
        // Arange
        let commonCrypto = CommonCryptoMock()
        commonCrypto.getJunctionResultFromEthereumBasedReturnValue = TestData.junctionResult

        let seedCreator = SeedCreatorImpl(commonCrypto: commonCrypto)

        // Act
        do {
            let result = try seedCreator.createSeed(
                derivationPath: TestData.derivationPath,
                strength: .entropy128,
                ethereumBased: false,
                cryptoType: .sr25519
            )

            // Assert
            XCTAssertEqual(commonCrypto.getJunctionResultFromEthereumBasedCallsCount, 1)
            XCTAssertEqual(result.seed.count, 32)
            XCTAssertNotEqual(result.mnemonic.toString(), "")
            XCTAssertEqual(result.mnemonic.numberOfWords(), 12)
        } catch {
            XCTFail("Create seed test failed with error - \(error)")
        }
    }

    func testDeriveSeed() {
        // Arange
        let commonCrypto = CommonCryptoMock()
        commonCrypto.getJunctionResultFromEthereumBasedReturnValue = TestData.junctionResult

        let seedCreator = SeedCreatorImpl(commonCrypto: commonCrypto)

        // Act
        do {
            let result = try seedCreator.deriveSeed(
                mnemonicWords: TestData.mnemonicString,
                derivationPath: TestData.derivationPath,
                ethereumBased: false,
                cryptoType: .sr25519
            )

            // Assert
            XCTAssertEqual(commonCrypto.getJunctionResultFromEthereumBasedCallsCount, 1)
            XCTAssertEqual(result.seed.toHex(), TestData.seed)
            XCTAssertNotEqual(result.mnemonic.toString(), "")
            XCTAssertEqual(result.mnemonic.numberOfWords(), 12)
        } catch {
            XCTFail("Derive seed test failed with error - \(error)")
        }
    }
}

extension SeedCreatorTests {
    enum TestData {
        static let derivationPath = ""
        static let mnemonicString =
            "street firm worth record skin taste legend lobster magnet stove drive side"
        static let seed = "bf57a61b1d24b6cde5a12f6779e9d13f7c59db72fc2a63bd382a6c91e7e41f61"
        static let junctionResult = JunctionResult(
            chaincodes: [],
            password: nil
        )
    }

    func performSeedCreatorTest(
        ethereumBased: Bool,
        cryptoTypes: [CryptoType]
    ) throws {
        let derivationPaths: [String] = [
            "",
            "/0",
            "//0",
            "/12//3",
        ]

        let strengths: [IRMnemonicStrength] = [
            .entropy128,
            .entropy160,
            .entropy192,
            .entropy224,
            .entropy256,
            .entropy288,
            .entropy320,
        ]

        for derivationPath in derivationPaths {
            for cryptoType in cryptoTypes {
                for strength in strengths {
                    let expectedResult = try seedCreator?.createSeed(
                        derivationPath: derivationPath,
                        strength: strength,
                        ethereumBased: ethereumBased,
                        cryptoType: cryptoType
                    )

                    let derivedResult = try seedCreator?.deriveSeed(
                        mnemonicWords: expectedResult?.mnemonic.toString() ?? "",
                        derivationPath: derivationPath,
                        ethereumBased: ethereumBased,
                        cryptoType: cryptoType
                    )

                    XCTAssertNotNil(expectedResult)
                    XCTAssertNotNil(derivedResult)

                    XCTAssertEqual(expectedResult?.seed, derivedResult?.seed)
                    XCTAssertEqual(
                        expectedResult?.mnemonic.toString(),
                        derivedResult?.mnemonic.toString()
                    )
                    XCTAssertEqual(
                        expectedResult?.mnemonic.entropy(),
                        derivedResult?.mnemonic.entropy()
                    )
                }
            }
        }
    }
}
