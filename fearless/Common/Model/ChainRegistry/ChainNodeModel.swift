import Foundation

struct ChainNodeModel: Codable, Hashable {
    let chainId: ChainModel.Id
    let url: URL
    let name: String
}
