import Foundation

final class NomisJSONDecoder: JSONDecoder, @unchecked Sendable {
    override init() {
        super.init()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        dateDecodingStrategy = .formatted(df)
    }
}
