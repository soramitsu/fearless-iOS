import Foundation

struct ChainNodeModel: Equatable, Codable, Hashable {
    struct ApiKey: Equatable, Codable, Hashable {
        let queryName: String
        let keyName: String
    }

    let url: URL
    let name: String
    let apikey: ApiKey?
}
