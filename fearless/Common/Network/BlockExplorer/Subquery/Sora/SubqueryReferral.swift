import Foundation

struct SubqueryReferral: Decodable {
    let to: String
    let from: String
    let amount: String?
}
