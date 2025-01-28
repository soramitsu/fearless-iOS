import Foundation
import TonSwift
import RobinHood

enum TonConnectAppConnectionType: String, Codable {
    case js
    case http
}

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
    let connectionType: TonConnectAppConnectionType

    enum CodingKeys: CodingKey {
        case walletId
        case clientId
        case appUrl
        case publicKey
        case privateKey
        case name
        case iconUrl
        case connectionType
    }

    var keyPair: TonSwift.KeyPair {
        TonSwift.KeyPair(
            publicKey: PublicKey(data: publicKey),
            privateKey: PrivateKey(data: privateKey)
        )
    }
}

extension TonConnectApp: WalletConnectActiveSessionsItem {
    var url: URL? {
        appUrl
    }
    
    var icon: URL? {
        iconUrl
    }
}
