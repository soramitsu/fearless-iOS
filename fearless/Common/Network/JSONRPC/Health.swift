import Foundation

struct Health: Codable {
    let isSyncing: Bool
    let peers: Int
    let shouldHavePeers: Bool
}
