import Foundation

final class MoonbeamJSONDecoder: JSONDecoder {
    static let moonbeamDateFormat: String = "yyyy-mm-dd'T'HH:mm:ss.SSSSSS"

    override init() {
        super.init()

        dateDecodingStrategy = .formatted(moonbeamDateFormatter)
        keyDecodingStrategy = .convertFromSnakeCase
    }

    private var moonbeamDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = MoonbeamJSONDecoder.moonbeamDateFormat

        return dateFormatter
    }
}
