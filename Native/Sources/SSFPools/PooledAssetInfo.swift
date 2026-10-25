import Foundation

public struct PooledAssetInfo {
    public let id: String
    public let precision: Int16

    public init(id: String, precision: Int16) {
        self.id = id
        self.precision = precision
    }
}
