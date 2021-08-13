import Foundation

struct ConnectionRank {
    let url: URL
    let rank: Int32
}

protocol ConnectionAutobalancing {
    var ranking: [ConnectionRank] { get }
    func set(ranking: [ConnectionRank])
}

extension ConnectionRank {
    init(chainNode: ChainNodeModel) {
        url = chainNode.url
        rank = 0
    }
}
