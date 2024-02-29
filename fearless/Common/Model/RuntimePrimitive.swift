import Foundation

public enum RuntimePrimitive: String {
    case bool
    case char
    case string = "str"
    case u8
    case u16
    case u32
    case u64
    case u128
    case u256
    case i8
    case i16
    case i32
    case i64
    case i128
    case i256
    case accountId = "AccountId"

    var bytesCount: Int {
        switch self {
        case .bool:
            return 1
        case .char:
            return 1
        case .string:
            return 40
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
        case .i8:
            return 1
        case .i16:
            return 2
        case .i32:
            return 4
        case .i64:
            return 8
        case .i128:
            return 16
        case .i256:
            return 32
        case .accountId:
            return 32
        }
    }
}
