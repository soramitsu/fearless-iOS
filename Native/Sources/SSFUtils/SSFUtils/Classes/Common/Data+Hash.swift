import Foundation
import IrohaCrypto
import xxHash_Swift

public extension Data {
    func blake128Concat() throws -> Data {
        let hashed = try blake2b16()
        return hashed + self
    }

    func twox128() -> Data {
        var hash1Value = XXH64.digest(self, seed: 0)
        let hash1 = Data(bytes: &hash1Value, count: MemoryLayout<UInt64>.size)

        var hash2Value = XXH64.digest(self, seed: 1)
        let hash2 = Data(bytes: &hash2Value, count: MemoryLayout<UInt64>.size)

        return hash1 + hash2
    }

    func twox256() -> Data {
        var hash1Value = XXH64.digest(self, seed: 0)
        let hash1 = Data(bytes: &hash1Value, count: MemoryLayout<UInt64>.size)

        var hash2Value = XXH64.digest(self, seed: 1)
        let hash2 = Data(bytes: &hash2Value, count: MemoryLayout<UInt64>.size)

        var hash3Value = XXH64.digest(self, seed: 2)
        let hash3 = Data(bytes: &hash3Value, count: MemoryLayout<UInt64>.size)

        var hash4Value = XXH64.digest(self, seed: 3)
        let hash4 = Data(bytes: &hash4Value, count: MemoryLayout<UInt64>.size)

        return hash1 + hash2 + hash3 + hash4
    }

    func twox64Concat() -> Data {
        var hash1Value = XXH64.digest(self, seed: 0)
        return Data(bytes: &hash1Value, count: MemoryLayout<UInt64>.size) + self
    }

    func blake2b16() throws -> Data {
        try (self as NSData).blake2b(16)
    }

    func blake2b32() throws -> Data {
        try (self as NSData).blake2b(32)
    }
}
