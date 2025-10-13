import Foundation

public struct GraphQLError: Decodable, Error {
    public let message: String?
}

public enum GraphQLResponse<T: Decodable>: Decodable {
    case data(T)
    case errors(GraphQLError)

    private struct Raw: Decodable {
        let data: T?
        let errors: [GraphQLError]?
    }

    public init(from decoder: Decoder) throws {
        let raw = try Raw(from: decoder)
        if let errs = raw.errors, let first = errs.first {
            self = .errors(first)
        } else if let d = raw.data {
            self = .data(d)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "GraphQLResponse missing both data and errors")
            )
        }
    }
}
