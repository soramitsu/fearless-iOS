import Foundation

struct MoonbeamAgreeRemarkInfo: Encodable {
    let address: String
    let signedMessage: Data

    enum CodingKeys: String, CodingKey {
        case address
        case signedMessage = "signed-message"
    }
}
