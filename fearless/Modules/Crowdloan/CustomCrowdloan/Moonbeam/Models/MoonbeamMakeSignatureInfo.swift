import Foundation

struct MoonbeamMakeSignatureInfo: Encodable {
    let address: String
    let previousTotalContribution: String
    let contribution: String
    let guid: String

    enum CodingKeys: String, CodingKey {
        case address
        case previousTotalContribution = "previous-total-contribution"
        case contribution
        case guid
    }
}
