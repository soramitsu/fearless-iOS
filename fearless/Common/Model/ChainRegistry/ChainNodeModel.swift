import Foundation

struct ChainNodeModel: Codable {
    let chainId: ChainModel.Id
    let url: URL
    let name: String
    let rank: Int32
}
