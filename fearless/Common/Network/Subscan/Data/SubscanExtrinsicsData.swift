import Foundation
import FearlessUtils

struct SubscanExtrinsicsData: Decodable {
    let count: Int
    let extrinsics: [SubscanExtrinsicsItemData]
}

struct SubscanExtrinsicsItemData: Decodable {

    let params: [SubscanExtrinsicsParam]

    private enum CodingKeys: String, CodingKey {
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let string = try container.decode(String.self, forKey: .params)
        guard let data = string.data(using: .utf8) else {
            throw DecodingError.dataCorruptedError(
                forKey: CodingKeys.params,
                in: container,
                debugDescription: "Unable to parse extrinsics params")
        }
        params = try JSONDecoder().decode([SubscanExtrinsicsParam].self, from: data)
    }
}

struct SubscanExtrinsicsParam: Decodable {
    let name: String
    let type: String
    let value: String
}

extension SubscanExtrinsicsParam {

    var controllerAddress: String? {
        if name == "controller" && type == "Address" {
            return value
        }
        return nil
    }
}
