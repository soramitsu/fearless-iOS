import Foundation
import xxHash_Swift

extension Data {
    func xxh128() -> Data {
        var hash1Value = XXH64.digest(self, seed: 0)
        let hash1 = Data(bytes: &hash1Value, count: MemoryLayout<UInt64>.size)

        var hash2Value = XXH64.digest(self, seed: 1)
        let hash2 = Data(bytes: &hash2Value, count: MemoryLayout<UInt64>.size)

        return hash1 + hash2
    }
}
