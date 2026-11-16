import Foundation

final class NomisJSONDecoder: JSONDecoder, @unchecked Sendable {
    override init() {
        super.init()
        let df = DateFormatter()
        // A fixed format must not follow the device's calendar or locale: with the Japanese calendar the year 2024
        // parsed as 4042.
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        dateDecodingStrategy = .formatted(df)
    }
}
