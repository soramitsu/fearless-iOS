import Foundation

struct AssetModel: Equatable, Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = UInt32
    typealias PriceId = String

    let assetId: Id
    let icon: URL?
    let name: String?
    let symbol: String
    let precision: UInt16
    let priceId: PriceId?
    let staking: String?

    var isUtility: Bool { assetId == 0 }
}
