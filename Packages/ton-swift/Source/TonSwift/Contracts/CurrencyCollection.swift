import Foundation
import BigInt

/// Implements ExtraCurrencyCollection per TLB schema:
///
/// ```
/// extra_currencies$_ dict:(HashmapE 32 (VarUInteger 32)) = ExtraCurrencyCollection;
/// ```
public typealias ExtraCurrencyCollection = [UInt32: VarUInt248]

/// Implements CurrencyCollection per TLB schema:
///
/// ```
/// currencies$_ grams:Grams other:ExtraCurrencyCollection = CurrencyCollection;
/// ```
public struct CurrencyCollection: CellCodable {
    public let coins: Coins
    public let other: ExtraCurrencyCollection
    
    init(coins: Coins, other: ExtraCurrencyCollection = [:]) {
        self.coins = coins
        self.other = other
    }
    
    public static func loadFrom(slice: Slice) throws -> CurrencyCollection {
        let coins = try slice.loadCoins()
        let other: ExtraCurrencyCollection = try slice.loadType()
        return CurrencyCollection(coins: coins, other: other)
    }
    
    public func storeTo(builder: Builder) throws {
        try builder.store(coins: coins)
        try builder.store(other)
    }
}
