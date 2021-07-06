import Foundation

struct BeaconConnectionInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case type
        case version
        case name
        case icon
        case appUrl
        case publicKey
        case relayServer
    }

    let identifier: String
    let type: String
    let version: String
    let name: String
    let icon: String?
    let appUrl: String?
    let publicKey: String
    let relayServer: String
}
