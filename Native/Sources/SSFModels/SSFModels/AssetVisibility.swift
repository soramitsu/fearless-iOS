import Foundation
import RobinHood

public struct AssetVisibility: Codable, Equatable, Hashable, Identifiable {
    public var identifier: String {
        assetId
    }

    public let assetId: String
    public var hidden: Bool

    public init(assetId: String, hidden: Bool) {
        self.assetId = assetId
        self.hidden = hidden
    }
}
