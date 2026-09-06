import Foundation

struct AlchemyHistoryElementMetadata: Codable {
    let blockTimestamp: String
}

struct AlchemyHistoryElement: Codable {
    let blockNum: String
    let uniqueId: String
    let hash: String
    let from: String
    let to: String?
    let value: Decimal?
    let asset: String?
    let category: String
    let metadata: AlchemyHistoryElementMetadata?
    let rawContract: AlchemyHistoryRawContract?

    var timestampInSeconds: Int64 {
        guard let dateString = metadata?.blockTimestamp else {
            return 0
        }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fractionalDate = dateFormatter.date(from: dateString)
        dateFormatter.formatOptions = [.withInternetDateTime]
        let date = fractionalDate ?? dateFormatter.date(from: dateString)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

struct AlchemyHistory: Decodable {
    let transfers: [AlchemyHistoryElement]
    let pageKey: String?
}

struct AlchemyHistoryRawContract: Codable {
    let value: String?
    let address: String?
    let decimal: String?
}
