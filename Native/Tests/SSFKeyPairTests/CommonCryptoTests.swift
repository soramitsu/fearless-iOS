import BigInt
import IrohaCrypto
import SSFCrypto
import SSFModels
import SSFUtils
import XCTest

@testable import SSFKeyPair

final class CommonCryptoTests: XCTestCase {
    var commonCrypto: CommonCrypto?

    override func setUp() {
        super.setUp()
        let commonCrypto = CommonCryptoImpl()
        self.commonCrypto = commonCrypto
    }

    override func tearDown() {
        super.tearDown()
        commonCrypto = nil
    }

    func testEmptyGetJunctionResult() {
        // Act
        do {
            let result = try commonCrypto?.getJunctionResult(
                from: TestData.emptyPath,
                ethereumBased: false
            )

            // Assert
            XCTAssertNil(result)
        } catch {
            XCTFail("Empty get junction test failed with error - \(error)")
        }
    }

    func testGetJunctionResultWithError() {
        // Act
        XCTAssertThrowsError(try commonCrypto?.getJunctionResult(
            from: TestData.errorPath,
            ethereumBased: false
        )) { error in
            // Assert
            XCTAssertEqual(
                error.localizedDescription,
                JunctionFactoryError.invalidStart.localizedDescription
            )
        }
    }

    func testGetJunctionResult() {
        // Act
        do {
            let result = try commonCrypto?.getJunctionResult(
                from: TestData.derivationPath,
                ethereumBased: false
            )

            // Assert
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.chaincodes.count, 1)
            XCTAssertEqual(result?.chaincodes.first?.type, .soft)
            XCTAssertEqual(result?.password, "password")
        } catch {
            XCTFail("Get junction test failed with error - \(error)")
        }
    }

    func testCreateKeypairFactory() {
        // Act
        let factory = commonCrypto?.createKeypairFactory(.ed25519, isEthereumBased: false)

        // Assert
        XCTAssertNotNil(factory)
        XCTAssertTrue(factory is Ed25519KeypairFactory)
    }

    func testGenerateKeypairWithError() {
        // Act
        XCTAssertThrowsError(try commonCrypto?.generateKeypair(
            from: Data(hexStringSSF: TestData.hexString),
            chaincodes: [TestData.chaincode],
            cryptoType: .ed25519,
            isEthereum: false
        )) { error in
            // Assert
            XCTAssertEqual(
                error.localizedDescription,
                KeypairFactoryError.unsupportedChaincodeType.localizedDescription
            )
        }
    }

    func testGetQuery() {
        // Act
        do {
            let result = try commonCrypto?.getQuery(
                seed: Data(hexStringSSF: TestData.hexString),
                derivationPath: "",
                cryptoType: .sr25519,
                ethereumBased: false
            )

            // Assert
            let keypair = try commonCrypto?.generateKeypair(
                from: Data(hexStringSSF: TestData.hexString),
                chaincodes: [],
                cryptoType: .sr25519,
                isEthereum: false
            )

            let addressString = try keypair?.publicKey.publicKeyToAccountId().toHex()
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.address.toHex(), addressString)
        } catch {
            XCTFail("Generate keypair test failed with error - \(error)")
        }
    }
}

extension CommonCryptoTests {
    enum TestData {
        static let emptyPath = ""
        static let errorPath = "1"
        static let derivationPath = "/chaincode///password"
        static let hexString = "0xbf57a61b1d24b6cde5a12f6779e9d13f7c59db72fc2a63bd382a6c91e7e41f61"
        static let chaincode = Chaincode(
            data: Data(),
            type: .soft
        )
    }
}
