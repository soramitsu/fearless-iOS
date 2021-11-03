import Foundation

struct AcalaTransferInfo: Encodable {
    let address: String
    let amount: String
    let referral: String?
    let email: String?
    let receiveEmail: Bool?
}
