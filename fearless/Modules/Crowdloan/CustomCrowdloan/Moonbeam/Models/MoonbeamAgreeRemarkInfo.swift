import Foundation

struct MoonbeamAgreeRemarkInfo: Encodable {
    let address: String
    let signedMessage: String

    enum CodingKeys: String, CodingKey {
        case address
        case signedMessage = "signed-message"
    }
}
