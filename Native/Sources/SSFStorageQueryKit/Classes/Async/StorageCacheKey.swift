import Foundation
import SSFUtils

/// A versioned namespace keeps identical runtime keys from different chains apart.
/// The suffix remains the original key so NMap/prefix cache decoding is unchanged.
enum StorageCacheKey {
    private static func prefix(chainId: String) -> String {
        "storage-v1/" + Data(chainId.utf8).toHex() + "/"
    }

    static func encode(remoteKey: Data, chainId: String) -> String {
        prefix(chainId: chainId) + remoteKey.toHex()
    }

    static func remoteKey(from identifier: String, chainId: String) -> Data? {
        let namespace = prefix(chainId: chainId)
        guard identifier.hasPrefix(namespace) else { return nil }
        let hex = String(identifier.dropFirst(namespace.count))
        guard !hex.isEmpty, hex.count.isMultiple(of: 2),
              hex.utf8.allSatisfy({ (48 ... 57).contains($0) || (97 ... 102).contains($0) }) else {
            return nil
        }
        return try? Data(hexStringSSF: hex)
    }
}
