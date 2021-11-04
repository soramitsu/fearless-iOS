import Foundation

struct MoonbeamAgreeRemarkData: Decodable {
    let address: String
    let signedMessage: String
    let remark: String

    enum CodingKeys: String, CodingKey {
        case address
        case signedMessage = "signed-message"
        case remark
    }
}
