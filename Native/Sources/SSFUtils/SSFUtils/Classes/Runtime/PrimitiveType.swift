import Foundation

public enum PrimitiveType: String, CaseIterable {
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
    case string
    case bool

    public var name: String { rawValue }
}
