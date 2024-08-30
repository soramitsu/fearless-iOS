import Foundation
import TonSwift
import RobinHood

struct TonConnectApp: Codable, Identifiable {
    var identifier: String {
        [walletId, appUrl.absoluteString].joined(separator: "-")
    }

    let walletId: String
    let clientId: String
    let appUrl: URL
    let name: String
    let iconUrl: URL?
    let publicKey: Data
    let privateKey: Data

    enum CodingKeys: CodingKey {
        case walletId
        case clientId
        case appUrl
        case publicKey
        case privateKey
        case name
        case iconUrl
    }

    var keyPair: TonSwift.KeyPair {
        TonSwift.KeyPair(
            publicKey: PublicKey(data: publicKey),
            privateKey: PrivateKey(data: privateKey)
        )
    }
}
