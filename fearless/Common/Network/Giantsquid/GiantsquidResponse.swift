import Foundation

struct GiantsquidResponse: Decodable {
    let data: GiantsquidResponseData
}

struct GiantsquidResponseData: Decodable {
    let transfers: [GiantsquidTransfer]
    let rewards: [GiantsquidReward]
    let bonds: [GiantsquidBond]
    let slashes: [GiantsquidSlash]

    var history: [WalletRemoteHistoryItemProtocol] {
        transfers + rewards + bonds + slashes
    }
}
