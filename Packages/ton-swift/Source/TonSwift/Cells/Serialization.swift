import Foundation

/// Types implementing both reading and writing
public protocol CellCodable {
    func storeTo(builder: Builder) throws
    static func loadFrom(slice: Slice) throws -> Self
}

/// Types implement KnownSize protocol when they have statically-known size in bits
public protocol StaticSize {
    /// Size of the type in bits
    static var bitWidth: Int { get }
}

/// Every type that can be used as a dictionary value has an accompanying coder object configured to read that type.
/// This protocol allows implement dependent types because the exact instance would have runtime parameter such as bitlength for the values of this type.
public protocol TypeCoder {
    associatedtype T
    func storeValue(_ src: T, to builder: Builder) throws
    func loadValue(from src: Slice) throws -> T
}

extension CellCodable {
    static func defaultCoder() -> some TypeCoder {
        DefaultCoder<Self>()
    }
}

public class DefaultCoder<X: CellCodable>: TypeCoder {
    public typealias T = X
    public func storeValue(_ src: T, to builder: Builder) throws {
        try src.storeTo(builder: builder)
    }
    public func loadValue(from src: Slice) throws -> T {
        return try T.loadFrom(slice: src)
    }
}

public extension TypeCoder {
    /// Serializes type to Cell
    func serializeToCell(_ src: T) throws -> Cell {
        let b = Builder()
        try storeValue(src, to: b)
        return try b.endCell()
    }
}


public class BytesCoder: TypeCoder {
    public typealias T = Data
    let size: Int
    
    init(size: Int) {
        self.size = size
    }
    
    public func storeValue(_ src: T, to builder: Builder) throws {
        try builder.store(data: src)
    }
    public func loadValue(from src: Slice) throws -> T {
        return try src.loadBytes(self.size)
    }
}

// Cell is encoded as a separate ref
extension Cell: CellCodable {
    public func storeTo(builder: Builder) throws {
        try builder.store(ref: self)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return try slice.loadRef()
    }
}

// Slice is encoded inline
extension Slice: CellCodable {
    public func storeTo(builder: Builder) throws {
        try builder.store(slice: self)
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return slice.clone() as! Self
    }
}

// Builder is encoded inline
extension Builder: CellCodable {
    public func storeTo(builder: Builder) throws {
        try builder.store(slice: endCell().beginParse())
    }
    
    public static func loadFrom(slice: Slice) throws -> Self {
        return try slice.clone().toBuilder() as! Self
    }
}

/// Empty struct to store empty leafs in the dictionaries to form sets.
public struct Empty: CellCodable {
    public static func loadFrom(slice: Slice) throws -> Self {
        return Empty()
    }
    public func storeTo(builder: Builder) throws {
        // store nothing
    }
}
