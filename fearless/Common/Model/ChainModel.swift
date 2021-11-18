import Foundation
import RobinHood

struct ChainModel: Codable, Equatable {
    var chainId: String
    var name: String
    var externalApi: ChainExternalApi?

    static func == (lhs: ChainModel, rhs: ChainModel) -> Bool {
        lhs.chainId == rhs.chainId && lhs.externalApi == rhs.externalApi
    }
}

struct ChainExternalApi: Codable, Equatable {
    var staking: ChainExternalApiObject
    var history: ChainExternalApiObject

    static func == (lhs: ChainExternalApi, rhs: ChainExternalApi) -> Bool {
        lhs.staking == rhs.staking && lhs.history == rhs.history
    }
}

struct ChainExternalApiObject: Codable {
    var type: String
    var url: String

    static func == (lhs: ChainExternalApiObject, rhs: ChainExternalApiObject) -> Bool {
        lhs.type == rhs.type && lhs.url == rhs.url
    }
}
