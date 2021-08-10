import Foundation

struct ChainNodeModel: Codable, Equatable {
    let chainId: ChainModel.Id
    let url: URL
    let name: String
}
