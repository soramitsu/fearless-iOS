import Foundation

public struct Health: Decodable {
    let isSyncing: Bool
    let peers: Int
    let shouldHavePeers: Bool
}
