import Foundation

struct AssetModel: Codable, Equatable {
    typealias Id = UInt32

    let assetId: Id
    let chainId: ChainModel.Id
    let name: String
    let symbol: String
    let precision: UInt16
    let isUtility: Bool
}
