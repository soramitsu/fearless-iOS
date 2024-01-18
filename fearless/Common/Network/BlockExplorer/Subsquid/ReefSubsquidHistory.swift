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

struct ReefResponseStakingEdge: Decodable {
    let node: GiantsquidReward
}

struct ReefResponseStakingConnection: Decodable {
    let edges: [ReefResponseStakingEdge]
    let totalCount: Int
}

struct ReefResponseData: Decodable {
    let transfers: [GiantsquidTransfer]?
    let stakingsConnection: ReefResponseStakingConnection?

    var history: [WalletRemoteHistoryItemProtocol] {
        let unwrappedTransfers = transfers ?? []
        let unwrappedRewards = stakingsConnection?.edges.map { $0.node } ?? []

        return unwrappedTransfers + unwrappedRewards
    }
}

extension ReefResponseData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        stakingsConnection?.edges.map { $0.node } ?? []
    }
}
