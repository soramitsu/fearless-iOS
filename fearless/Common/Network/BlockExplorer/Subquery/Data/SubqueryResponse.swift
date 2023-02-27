import Foundation
import FearlessUtils

struct SubqueryErrors: Error, Decodable {
    struct SubqueryError: Error, Decodable {
        let message: String
    }

    let errors: [SubqueryError]
}

enum SubqueryResponse<D: Decodable>: Decodable {
    case data(_ value: D)
    case errors(_ value: SubqueryErrors)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let json = try container.decode(JSON.self)

        if let data = json.data {
            let value = try data.map(to: D.self)
            self = .data(value)
        } else if let errors = json.errors {
            let values = try errors.map(to: [SubqueryErrors.SubqueryError].self)
            self = .errors(SubqueryErrors(errors: values))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }
}
