import Foundation

struct AcalaContributeInfo: Encodable {
    let address: String
    let amount: String
    let signature: String
    let referral: String?
    let email: String?
    let receiveEmail: Bool?
}
