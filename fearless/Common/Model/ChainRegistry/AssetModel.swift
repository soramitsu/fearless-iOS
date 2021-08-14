import Foundation

struct AssetModel: Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = UInt32

    let assetId: Id
    let chainId: ChainModel.Id
    let icon: URL?
    let name: String
    let symbol: String
    let precision: UInt16

    var isUtility: Bool { assetId == 0 }
}
