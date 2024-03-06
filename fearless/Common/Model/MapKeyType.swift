import Foundation

public enum MapKeyType: String {
    case u8
    case u16
    case u32
    case u64
    case u128
    case u256
    case accountId = "AccountId"

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
        }
    }
}
