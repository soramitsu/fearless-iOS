import Foundation

struct SubsquidCollatorAprResponse: Decodable {
    let stakers: [SubsquidCollatorAprInfo]
}

struct SubsquidCollatorAprInfo: Decodable, Equatable, CollatorAprInfoProtocol {
    enum CodingKeys: String, CodingKey {
        case apr24h
        case stashId
    }

    var stashId: String
    var apr24h: Double

    var apr: Double {
        apr24h
    }

    var collatorId: String {
        stashId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        stashId = try container.decode(String.self, forKey: .stashId)
        apr24h = try container.decodeIfPresent(Double.self, forKey: .apr24h) ?? 999
    }
}

extension SubsquidCollatorAprResponse: CollatorAprResponse {
    var collatorAprInfos: [CollatorAprInfoProtocol] {
        stakers
    }
}
