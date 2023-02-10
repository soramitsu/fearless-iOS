import Foundation

struct GiantsquidResponse: Decodable {
    let data: GiantsquidResponseData
}

struct GiantsquidResponseData: Decodable {
    let transfers: [GiantsquidTransferResponse]?
    let rewards: [GiantsquidReward]?
    let bonds: [GiantsquidBond]?
    let slashes: [GiantsquidSlash]?

    var history: [WalletRemoteHistoryItemProtocol] {
        let unwrappedTransfers = transfers?.map { $0.transfer } ?? []
        let unwrappedRewards = rewards ?? []
        let unwrappedBonds = bonds ?? []
        let unwrappedSlashes = slashes ?? []

        return unwrappedTransfers + unwrappedRewards + unwrappedBonds + unwrappedSlashes
    }
}
