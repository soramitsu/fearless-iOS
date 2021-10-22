import Foundation

final class MoonbeamJSONEncoder: JSONEncoder {
    override init() {
        super.init()

        keyEncodingStrategy = .convertToSnakeCase
    }
}
