import Foundation

struct PriceData: Decodable {
    let price: String
    let time: Int64
    let height: Int64
    let records: [PriceRecord]
}

struct PriceRecord: Decodable {
    let price: String
    let time: Int64
    let height: Int64
}
