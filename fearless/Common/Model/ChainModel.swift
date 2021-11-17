import Foundation

struct ChainModel: Codable, Equatable {
    var name: String
    var externalApi: ChainExternalApi?

    static func == (lhs: ChainModel, rhs: ChainModel) -> Bool {
        lhs.name == rhs.name && lhs.externalApi == rhs.externalApi
    }
}

struct ChainExternalApi: Codable, Equatable {
    var staking: ChainExternalApiObject
    var history: ChainExternalApiObject

    static func == (lhs: ChainExternalApi, rhs: ChainExternalApi) -> Bool {
        lhs.staking == rhs.staking && lhs.history == rhs.history
    }
}

struct ChainExternalApiObject: Codable, Equatable {
    var type: String
    var url: String

    static func == (lhs: ChainExternalApiObject, rhs: ChainExternalApiObject) -> Bool {
        lhs.type == rhs.type && lhs.url == rhs.url
    }
}
