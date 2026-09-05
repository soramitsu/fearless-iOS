import Foundation
import BigInt

/// All APIs that take bit as a parameter or return a bit are expressed using typealias `Bit` based on `Int`.
/// An API that produces `Bit` guarantees that it is in range `[0,1]`.
public typealias Bit = Int

/// Represents unary integer encoding: `0` for 0, `10` for 1, `110` for 2, `1{n}0` for n.
public struct Unary: CellCodable {
    public let value: Int
    
    init(_ v: Int) {
        value = v
    }
    
    public func storeTo(builder: Builder) throws {
        try builder.store(bit: 1, repeat: value)
        try builder.store(bit: 0)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        var v: Int = 0
        while try slice.loadBit() == 1 {
            v += 1
        }
        return Unary(v)
    }
}

extension Bool: CellCodable, StaticSize {
    public static var bitWidth: Int = 1
        
    public func storeTo(builder: Builder) throws {
        try builder.store(bit: self)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return try slice.loadBoolean()
    }
}

/// 256-bit unsigned integer
public struct UInt256: Hashable, CellCodable, StaticSize {
    public var value: BigUInt
    
    public static var bitWidth: Int = 256
    
    init(biguint: BigUInt) {
        value = biguint
    }
    
    public func storeTo(builder: Builder) throws {
        try builder.store(uint: value, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(biguint: try slice.loadUintBig(bits: Self.bitWidth))
    }
}

// Unsigned short integers

extension UInt8: CellCodable, StaticSize {
    public static var bitWidth: Int = 8
    
    public func storeTo(builder: Builder) throws {
        try builder.store(uint: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadUint(bits: Self.bitWidth))
    }
}

extension UInt16: CellCodable, StaticSize {
    public static var bitWidth: Int = 16
    
    public func storeTo(builder: Builder) throws {
        try builder.store(uint: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadUint(bits: Self.bitWidth))
    }
}

extension UInt32: CellCodable, StaticSize {
    public static var bitWidth: Int = 32
    
    public func storeTo(builder: Builder) throws {
        try builder.store(uint: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadUint(bits: Self.bitWidth))
    }
}

extension UInt64: CellCodable, StaticSize {
    public static var bitWidth: Int = 64
    
    public func storeTo(builder: Builder) throws {
        try builder.store(uint: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadUint(bits: Self.bitWidth))
    }
}

// Signed short integers

extension Int8: CellCodable, StaticSize {
    public static var bitWidth: Int = 8
    
    public func storeTo(builder: Builder) throws {
        try builder.store(int: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadInt(bits: Self.bitWidth))
    }
}

extension Int16: CellCodable, StaticSize {
    public static var bitWidth: Int = 16
    
    public func storeTo(builder: Builder) throws {
        try builder.store(int: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadInt(bits: Self.bitWidth))
    }
}

extension Int32: CellCodable, StaticSize {
    public static var bitWidth: Int = 32
    
    public func storeTo(builder: Builder) throws {
        try builder.store(int: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadInt(bits: Self.bitWidth))
    }
}

extension Int64: CellCodable, StaticSize {
    public static var bitWidth: Int = 64
    
    public func storeTo(builder: Builder) throws {
        try builder.store(int: self, bits: Self.bitWidth)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(try slice.loadInt(bits: Self.bitWidth))
    }
}



//
// Dynamically-sized integers
//

/// Up-to-31-byte (248-bit) unsigned integer (5-bit length prefix)
public struct VarUInt248: Hashable, CellCodable {
    public var value: BigUInt
    public func storeTo(builder: Builder) throws {
        try builder.store(varuint: value, limit: 32)
    }
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(value: try slice.loadVarUintBig(limit: 32))
    }
}

/// Up-to-15-byte (120-bit) unsigned integer (4-bit length prefix)
public struct VarUInt120: Hashable, CellCodable {
    public var value: BigUInt
    public func storeTo(builder: Builder) throws {
        try builder.store(varuint: value, limit: 16)
    }
    public static func loadFrom(slice: Slice) throws -> Self {
        return Self(value: try slice.loadVarUintBig(limit: 16))
    }
}

public struct IntCoder: TypeCoder {
    public typealias T = BigInt
    
    public let bits: Int
    
    public init(bits: Int) {
        self.bits = bits
    }
    
    public func storeValue(_ src: T, to builder: Builder) throws {
        try builder.store(int: src, bits: bits)
    }
    
    public func loadValue(from src: Slice) throws -> T {
        return try src.loadIntBig(bits: bits)
    }
}

public struct UIntCoder: TypeCoder {
    public typealias T = BigUInt
    
    public let bits: Int
     
    public init(bits: Int) {
        self.bits = bits
    }
    
    public func storeValue(_ src: T, to builder: Builder) throws {
        try builder.store(uint: src, bits: bits)
    }
    
    public func loadValue(from src: Slice) throws -> T {
        return try src.loadUintBig(bits: bits)
    }
}

/// Encodes variable-length integers using `limit` bound on integer size in _bytes_.
/// Therefore, `VarUIntCoder(32)` can represent 248-bit integers (lengths 0...31 bytes).
/// TL-B:
/// ```
/// var_uint$_ {n:#} len:(#< n) value:(uint (len * 8)) = VarUInteger n;
/// var_int$_  {n:#} len:(#< n) value:(int (len * 8))  = VarInteger n;
/// ```
public struct VarUIntCoder: TypeCoder {
    public typealias T = BigUInt
    
    public let limit: Int
    
    public init(limit: Int) {
        self.limit = limit
    }
    
    public func storeValue(_ src: T, to builder: Builder) throws {
        try builder.store(varuint: src, limit: limit)
    }
    
    public func loadValue(from src: Slice) throws -> T {
        return try src.loadVarUintBig(limit: limit)
    }
}
