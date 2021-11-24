import Foundation

enum CrowdloanAddMemoParam: Decodable {
    case index(Index)
    case memo(Memo)

    struct CommonInfo: Decodable {
        let name: String
    }

    struct Index: Decodable {
        let typeName: String
        let value: ParaId
    }

    struct Memo: Decodable {
        let typeName: String
        let value: String
    }

    init(from decoder: Decoder) throws {
        let commonInfo = try CommonInfo(from: decoder)
        switch commonInfo.name {
        case "index": self = .index(try Index(from: decoder))
        case "memo": self = .memo(try Memo(from: decoder))
        default: throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown parameter name \(commonInfo.name)", underlyingError: nil))
        }
    }
}
