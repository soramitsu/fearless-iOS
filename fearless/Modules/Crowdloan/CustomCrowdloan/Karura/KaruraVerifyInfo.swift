import Foundation

struct KaruraVerifyInfo: Encodable {
    let address: String
    let amount: String
    let signature: String
    let referral: String
}
