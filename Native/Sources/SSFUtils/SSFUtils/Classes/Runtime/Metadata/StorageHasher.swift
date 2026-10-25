import Foundation

public enum StorageHasher: UInt8 {
    case blake128
    case blake256
    case blake128Concat
    case twox128
    case twox256
    case twox64Concat
    case identity
}

public extension StorageHasher {
    func hash(data: Data) throws -> Data {
        switch self {
        case .blake128:
            return try data.blake2b16()
        case .blake256:
            return try data.blake2b32()
        case .blake128Concat:
            return try data.blake128Concat()
        case .twox128:
            return data.twox128()
        case .twox256:
            return data.twox256()
        case .twox64Concat:
            return data.twox64Concat()
        case .identity:
            return data
        }
    }
}
