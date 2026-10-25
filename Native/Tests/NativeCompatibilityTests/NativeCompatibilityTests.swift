import Darwin
import Foundation
import scrypt
import SoraKeystore
import SSFPools
import XCTest

final class NativeCompatibilityTests: XCTestCase {
    func testScryptMatchesRFC7914VectorWithoutWritingSecretMaterialToStdout() throws {
        let result = try captureStdout {
            deriveScrypt(
                password: [],
                salt: [],
                cost: 16,
                blockSize: 1,
                parallelization: 1,
                length: 64
            )
        }

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(
            result.bytes.map { String(format: "%02x", $0) }.joined(),
            "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442"
                + "fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906"
        )
        XCTAssertTrue(result.stdout.isEmpty, "scrypt must never print secret-derived buffers")
    }

    func testScryptRejectsNonPowerOfTwoCostWithoutOutput() throws {
        let result = try captureStdout {
            deriveScrypt(
                password: [0x73, 0x65, 0x63, 0x72, 0x65, 0x74],
                salt: [0x73, 0x61, 0x6C, 0x74],
                cost: 3,
                blockSize: 1,
                parallelization: 1,
                length: 32
            )
        }

        XCTAssertEqual(result.status, -1)
        XCTAssertTrue(result.stdout.isEmpty)
    }

    func testPoolValueTypesExposeStablePublicInitializers() {
        let base = SSFPools.PooledAssetInfo(id: "XOR", precision: 18)
        let target = SSFPools.PooledAssetInfo(id: "VAL", precision: 18)
        let supply = SupplyLiquidityInfo(
            dexId: "0",
            baseAsset: base,
            targetAsset: target,
            baseAssetAmount: 100,
            targetAssetAmount: 50,
            slippage: 1
        )
        let removal = RemoveLiquidityInfo(
            dexId: "0",
            baseAsset: base,
            targetAsset: target,
            baseAssetAmount: 100,
            targetAssetAmount: 50,
            baseAssetReserves: 1000,
            totalIssuances: 500,
            slippage: 1
        )

        XCTAssertEqual(base.id, "XOR")
        XCTAssertEqual(base.precision, 18)
        XCTAssertEqual(supply.amountMinA, 99)
        XCTAssertEqual(supply.amountMinB, 49.5)
        XCTAssertEqual(removal.amountMinA, 99)
        XCTAssertEqual(removal.amountMinB, 49.5)
    }

    func testScryptRejectsZeroBlockSizeAndParallelizationWithoutOutput() throws {
        for (blockSize, parallelization): (UInt32, UInt32) in [(0, 1), (1, 0)] {
            let result = try captureStdout {
                deriveScrypt(password: [], salt: [], cost: 16,
                             blockSize: blockSize, parallelization: parallelization, length: 32)
            }
            XCTAssertEqual(result.status, -1)
            XCTAssertEqual(result.bytes, [UInt8](repeating: 0, count: 32))
            XCTAssertTrue(result.stdout.isEmpty)
        }
    }

    func testBundledKeystoreClassesUseCollisionSafeObjectiveCNames() {
        XCTAssertEqual(NSStringFromClass(Keychain.self), "SSFSoraKeystoreKeychain")
        XCTAssertEqual(NSStringFromClass(KeychainManager.self), "SSFSoraKeystoreKeychainManager")
        XCTAssertEqual(NSStringFromClass(InMemoryKeychain.self), "SSFSoraKeystoreInMemoryKeychain")
        XCTAssertEqual(NSStringFromClass(SettingsManager.self), "SSFSoraKeystoreSettingsManager")
        XCTAssertEqual(
            NSStringFromClass(InMemorySettingsManager.self),
            "SSFSoraKeystoreInMemorySettingsManager"
        )
    }
}

private extension NativeCompatibilityTests {
    struct ScryptResult {
        let status: Int32
        let bytes: [UInt8]
        let stdout: Data
    }

    func deriveScrypt(
        password: [UInt8],
        salt: [UInt8],
        cost: UInt64,
        blockSize: UInt32,
        parallelization: UInt32,
        length: Int
    ) -> (status: Int32, bytes: [UInt8]) {
        var output = [UInt8](repeating: 0, count: length)
        let outputCount = output.count
        let status = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                output.withUnsafeMutableBytes { outputBytes in
                    crypto_scrypt(
                        passwordBytes.bindMemory(to: UInt8.self).baseAddress,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        cost,
                        blockSize,
                        parallelization,
                        outputBytes.bindMemory(to: UInt8.self).baseAddress,
                        outputCount
                    )
                }
            }
        }
        return (status, output)
    }

    func captureStdout(
        _ operation: () -> (status: Int32, bytes: [UInt8])
    ) throws -> ScryptResult {
        var descriptors = [Int32](repeating: -1, count: 2)
        guard pipe(&descriptors) == 0 else {
            throw POSIXError(.EIO)
        }

        let originalStdout = dup(STDOUT_FILENO)
        guard originalStdout >= 0 else {
            close(descriptors[0])
            close(descriptors[1])
            throw POSIXError(.EIO)
        }

        fflush(stdout)
        guard dup2(descriptors[1], STDOUT_FILENO) >= 0 else {
            close(originalStdout)
            close(descriptors[0])
            close(descriptors[1])
            throw POSIXError(.EIO)
        }
        close(descriptors[1])

        let result = operation()
        fflush(stdout)
        _ = dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)

        let captured = FileHandle(fileDescriptor: descriptors[0], closeOnDealloc: true)
            .readDataToEndOfFile()
        return ScryptResult(status: result.status, bytes: result.bytes, stdout: captured)
    }
}
