import BigInt
import IrohaCrypto
import SSFModels
import SSFUtils
import XCTest

@testable import SSFKeyPair

final class MnemonicCreatorTests: XCTestCase {
    func testRandomMnemonicStrength() {
        // Arrange
        let expectedStrength: IRMnemonicStrength = TestData.strength
        let mnemonicCreator = MnemonicCreatorImpl()

        // Act
        do {
            let result = try mnemonicCreator.randomMnemonic(strength: expectedStrength)

            // Assert
            XCTAssertNotEqual("", result.toString())
            XCTAssertEqual(12, result.allWords().count)
        } catch {
            XCTFail("Random mnemonic from strength test failed with error - \(error)")
        }
    }

    func testMnemonicFromPassphrase() {
        // Arrange
        let expectedPassphrase: String = TestData.mnemonicString
        let mnemonicCreator = MnemonicCreatorImpl()

        // Act
        do {
            let result = try mnemonicCreator.mnemonic(fromList: expectedPassphrase)

            // Assert
            XCTAssertNotEqual("", result.toString())
            XCTAssertEqual(12, result.allWords().count)
            XCTAssertEqual(expectedPassphrase, result.toString())
        } catch {
            XCTFail("Random mnemonic from strength test failed with error - \(error)")
        }
    }

    func testMnemonicFromEntropy() {
        // Arrange
        let expectedEntropy: Data = TestData.entropy
        let mnemonicCreator = MnemonicCreatorImpl()

        // Act
        do {
            let result = try mnemonicCreator.mnemonic(fromEntropy: expectedEntropy)

            // Assert
            XCTAssertNotEqual("", result.toString())
            XCTAssertEqual(12, result.allWords().count)
        } catch {
            XCTFail("Random mnemonic from strength test failed with error - \(error)")
        }
    }

    func testMnemonicFromEntropyWithError() {
        // Arrange
        let expectedEntropy: Data = TestData.errorEntropy
        let mnemonicCreator = MnemonicCreatorImpl()

        // Act
        XCTAssertThrowsError(try mnemonicCreator.mnemonic(fromEntropy: expectedEntropy)) { error in
            // Assert
            XCTAssertEqual(error.localizedDescription, "Invalid entropy length 12")
        }
    }
}

extension MnemonicCreatorTests {
    enum TestData {
        static let strength: IRMnemonicStrength = .entropy128
        static let mnemonicString: String =
            "street firm worth record skin taste legend lobster magnet stove drive side"
        static let entropy: Data = .init(count: 16)
        static let errorEntropy: Data = .init(count: 12)
    }
}
