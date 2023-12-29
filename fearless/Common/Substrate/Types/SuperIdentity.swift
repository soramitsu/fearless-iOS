import Foundation
import SSFUtils

struct SuperIdentity: Codable {
    let parentAccountId: Data
    let data: ChainData

    var name: String? {
        if case let .raw(value) = data {
            return String(data: value, encoding: .utf8)
        } else {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        do {
            parentAccountId = try container.decode(Data.self)
        } catch {
            let parentAccountIdString = try container.decode(String.self)
            parentAccountId = Data(hex: parentAccountIdString)
        }
        data = try container.decode(ChainData.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(parentAccountId)
        try container.encode(data)
    }
}
