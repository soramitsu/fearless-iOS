import Foundation
import BigInt

/// 128-bit integer representing base TON currency: toncoins (aka `grams` in block.tlb).
public struct Coins {
    var amount: BigUInt
    
    init(_ a: some BinaryInteger) {
        // we use signed integer here because of `0` literal is a signed Int.
        self.amount = BigUInt(a)
    }
}

extension Coins: RawRepresentable {
    public typealias RawValue = BigUInt;

    public init?(rawValue: BigUInt) {
        self.amount = rawValue
    }

    public var rawValue: BigUInt {
        return self.amount
    }
}

extension Coins: CellCodable {
    public func storeTo(builder: Builder) throws {
        try builder.store(varuint: self.amount, limit: 16)
    }
    public static func loadFrom(slice: Slice) throws -> Coins {
        return Coins(try slice.loadVarUintBig(limit: 16))
    }
}

extension Slice {
    /// Loads Coins value
    public func loadCoins() throws -> Coins {
        return try loadType()
    }
    
    /// Preloads Coins value
    public func preloadCoins() throws -> Coins {
        return try preloadType()
    }
    
    /// Load optionals Coins value.
    public func loadMaybeCoins() throws -> Coins? {
        if try loadBoolean() {
            return try loadCoins()
        }
        return nil
    }
}

extension Builder {
    
    /// Write coins amount in varuint format
    @discardableResult
    func store(coins: Coins) throws -> Self {
        return try store(varuint: coins.amount, limit: 16)
    }
    
    /**
     * Store optional coins value
     * @param amount amount of coins, null or undefined
     * @returns this builder
     */
    @discardableResult
    public func storeMaybe(coins: Coins?) throws -> Self {
        if let coins {
            try store(bit: true)
            try store(coins: coins)
        } else {
            try store(bit: false)
        }
        return self
    }

}
