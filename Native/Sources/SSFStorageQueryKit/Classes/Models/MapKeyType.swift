import Foundation

public enum MapKeyType: String {
    case u8
    case u16
    case u32
    case u64
    case u128
    case u256
    case accountId = "AccountId"
    case assetIds
    case accountPoolsKey
    case poolProvidersKey

    var bytesCount: Int {
        switch self {
        case .u8:
            return 1
        case .u16:
            return 2
        case .u32:
            return 4
        case .u64:
            return 8
        case .u128:
            return 16
        case .u256:
            return 32
        case .accountId:
            return 32
        case .assetIds:
            return 32
        case .accountPoolsKey:
            return 32
        case .poolProvidersKey:
            return 32
        }
    }
    
    func extractKeys(from storageResponseKey: String) -> String {
        let bytesPerHexSymbol = 2

        switch self {
        case .u8, .u16, .u32, .u64, .u128, .u256, .accountId:
            return String(storageResponseKey.suffix(bytesCount * bytesPerHexSymbol))
        case .assetIds:
            let hasherBytes = 32
            let parameterLength = bytesCount * bytesPerHexSymbol
            let secondAssetId = String(storageResponseKey.suffix(parameterLength))
            let firstAssetId = String(storageResponseKey.suffix(parameterLength * 2 + hasherBytes)).prefix(parameterLength)
            return firstAssetId + secondAssetId
        case .accountPoolsKey:
            let hasherBytes = 32
            let parameterLength = bytesCount * bytesPerHexSymbol
            let assetId = String(storageResponseKey.suffix(parameterLength))
            let accountId = String(storageResponseKey.suffix(parameterLength * 2 + hasherBytes)).prefix(parameterLength)

            return accountId + assetId
        case .poolProvidersKey:
            let parameterLength = bytesCount * bytesPerHexSymbol
            let assetId = String(storageResponseKey.suffix(parameterLength))
            let accountId = String(storageResponseKey.suffix(parameterLength * 2)).prefix(parameterLength)

            return accountId + assetId
        }
    }
}
