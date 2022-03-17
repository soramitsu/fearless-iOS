import Foundation

final class GithubJSONDecoder: JSONDecoder {
    override init() {
        super.init()

        keyDecodingStrategy = .convertFromSnakeCase
    }
}
