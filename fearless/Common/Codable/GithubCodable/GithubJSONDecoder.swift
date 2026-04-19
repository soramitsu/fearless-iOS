import Foundation

final class GithubJSONDecoder: JSONDecoder, @unchecked Sendable {
    override init() {
        super.init()

        keyDecodingStrategy = .convertFromSnakeCase
    }
}
