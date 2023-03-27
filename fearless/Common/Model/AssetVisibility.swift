import Foundation
import RobinHood

struct AssetVisibility: Codable, Equatable, Hashable, Identifiable {
    var identifier: String {
        assetId
    }

    let assetId: String
    var hidden: Bool
}
