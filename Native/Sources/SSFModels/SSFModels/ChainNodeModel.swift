import Foundation

public struct ChainNodeModel: Equatable, Codable, Hashable {
    public struct ApiKey: Equatable, Codable, Hashable {
        public let queryName: String
        public let keyName: String

        public init(queryName: String, keyName: String) {
            self.queryName = queryName
            self.keyName = keyName
        }
    }

    public let url: URL
    public let name: String
    public let apikey: ApiKey?

    public init(url: URL, name: String, apikey: ChainNodeModel.ApiKey?) {
        self.url = url
        self.name = name
        self.apikey = apikey
    }
}

public extension ChainNodeModel {
    var clearUrlString: String? {
        url.absoluteString.components(separatedBy: "?api").first
    }
}
