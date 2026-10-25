import Foundation

enum AssetKeyExtractionError: Error {
    case invalidSize
}

public extension String {
    func assetIdFromKey() throws -> String {
        guard count > 64 else {
            throw AssetKeyExtractionError.invalidSize
        }
        return "0x" + suffix(64)
    }
}
