import Foundation

struct GiantsquidResponse: Decodable {
    let data: GiantsquidResponseData
}

struct GiantsquidResponseData: Decodable {
    let transfers: [GiantsquidTransferResponse]?
    let stakingRewards: [GiantsquidReward]?
    let bonds: [GiantsquidBond]?
    let slashes: [GiantsquidSlash]?

    var history: [WalletRemoteHistoryItemProtocol] {
        let unwrappedTransfers = transfers?.map { $0.transfer } ?? []
        let unwrappedRewards = stakingRewards ?? []
        let unwrappedBonds = bonds ?? []
        let unwrappedSlashes = slashes ?? []

        return unwrappedTransfers + unwrappedRewards + unwrappedBonds + unwrappedSlashes
    }
}

extension GiantsquidResponseData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        stakingRewards ?? []
    }
}
