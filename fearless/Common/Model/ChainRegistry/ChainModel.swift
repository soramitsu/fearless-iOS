import Foundation
import RobinHood

struct ChainModel: Codable, Equatable {
    // swiftlint:disable type_name
    typealias Id = String

    let chainId: Id
    let assets: [AssetModel]
    let nodes: [ChainNodeModel]
    let prefix: UInt16
    let typesURL: URL
    let preferredUrl: URL?
    let isEthereum: Bool
}

extension ChainModel: Identifiable {
    var identifier: String { chainId }
}
