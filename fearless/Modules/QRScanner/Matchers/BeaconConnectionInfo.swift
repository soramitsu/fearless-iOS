import Foundation

struct BeaconConnectionInfo: Decodable {
    let name: String
    let icon: String?
    let appUrl: String?
    let publicKey: String?
    let relayServer: String
}
