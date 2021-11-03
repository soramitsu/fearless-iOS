import Foundation

struct MoonbeamMakeSignatureData: Decodable {
    let address: String
    let previousTotalContribution: String
    let contribution: String
    let signature: String
    let guid: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case address
        case previousTotalContribution = "previous-total-contribution"
        case contribution
        case signature
        case guid
        case timestamp = "time-stamp"
    }
}
