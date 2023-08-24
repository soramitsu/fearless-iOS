import Foundation

struct AlchemyHistoryElementMetadata: Decodable {
    let blockTimestamp: String
}

struct AlchemyHistoryElement: Decodable {
    let blockNum: String
    let uniqueId: String
    let hash: String
    let from: String
    let to: String
    let value: Decimal
    let asset: String
    let category: String
    let metadata: AlchemyHistoryElementMetadata?

    var timestampInSeconds: Int64 {
        guard let dateString = metadata?.blockTimestamp else {
            return 0
        }
        let dateFormatter = DateFormatter.alchemyDate
        let date = dateFormatter.value(for: Locale.current).date(from: dateString)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

struct AlchemyHistory: Decodable {
    let transfers: [AlchemyHistoryElement]
}
