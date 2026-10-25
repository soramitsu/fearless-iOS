import Foundation

public struct TokenSymbol: Equatable, Hashable {
    public let symbol: String

    public init(symbol: String) {
        self.symbol = symbol
    }
}

extension TokenSymbol: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(symbol.uppercased())
        try container.encodeNil()
    }
}
