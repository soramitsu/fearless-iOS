import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let time: Int64
    let height: Int64
    let records: [PriceRecord]
}

struct PriceRecord: Codable, Equatable {
    let price: String
    let time: Int64
    let height: Int64
}
