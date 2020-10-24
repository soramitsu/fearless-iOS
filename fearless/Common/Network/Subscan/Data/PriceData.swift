import Foundation

struct PriceData: Codable {
    let price: String
    let time: Int64
    let height: Int64
    let records: [PriceRecord]
}

struct PriceRecord: Codable {
    let price: String
    let time: Int64
    let height: Int64
}
