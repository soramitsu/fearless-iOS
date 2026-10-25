import Foundation

public struct PriceProvider: Codable {
    public let type: PriceProviderType
    public let id: String
    public let precision: Int16?

    public init(type: PriceProviderType, id: String, precision: Int16?) {
        self.type = type
        self.id = id
        self.precision = precision
    }
}

extension PriceProvider: Equatable {}

public enum PriceProviderType: String, Codable {
    case chainlink
    case coingecko
    case sorasubquery
}
