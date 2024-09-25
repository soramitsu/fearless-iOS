import Foundation

enum OKXResponseDecodingError: Error {
    case invalidCode
}

struct OKXResponse<T: Decodable>: Decodable {
    enum CodingKeys: String, CodingKey {
        case code
        case data
        case msg
    }

    let code: String
    let data: [T]
    let msg: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var code: String?
        if let stringCode = try? container.decode(String.self, forKey: .code) {
            code = stringCode
        }

        if let intCode = try? container.decode(Int64.self, forKey: .code) {
            code = "\(intCode)"
        }

        guard let code else {
            throw OKXResponseDecodingError.invalidCode
        }

        self.code = code
        data = try container.decode([T].self, forKey: .data)
        msg = try? container.decodeIfPresent(String.self, forKey: .msg)
    }
}
