import Foundation
import RobinHood

struct AssetModel: Equatable, Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String
    typealias PriceId = String

    let id: String
    let chainId: String
    let precision: UInt16
    let icon: URL?
    let priceId: PriceId?

    var isUtility: Bool { id.isEmpty }
}

extension AssetModel: Identifiable {
    var identifier: String { id }
}
