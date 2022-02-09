import Foundation
import RobinHood

struct ChainNodeModel: Equatable, Codable, Hashable {
    struct ApiKey: Equatable, Codable, Hashable {
        let queryName: String
        let keyName: String
    }

    let url: URL
    let name: String
    let apikey: ApiKey?
}

extension ChainNodeModel: Identifiable {
    var identifier: String { url.absoluteString }
}

extension ChainNodeModel {
    var clearUrlString: String? {
        url.absoluteString.components(separatedBy: "?api").first
    }
}
