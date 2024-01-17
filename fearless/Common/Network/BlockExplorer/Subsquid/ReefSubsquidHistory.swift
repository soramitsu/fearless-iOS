import Foundation
import BigInt
import CommonWallet
import IrohaCrypto
import SoraFoundation
import SSFModels

struct ReefDestination: Decodable {
    let id: String
}

struct ReefResponse: Decodable {
    let data: GiantsquidResponseData
}

struct ReefResponseData: Decodable {
    let transfers: [GiantsquidTransfer]?
    let stakings: [GiantsquidReward]?

    var history: [WalletRemoteHistoryItemProtocol] {
        let unwrappedTransfers = transfers ?? []
        let unwrappedRewards = stakings ?? []

        return unwrappedTransfers + unwrappedRewards
    }
}

extension ReefResponseData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        stakings ?? []
    }
}
