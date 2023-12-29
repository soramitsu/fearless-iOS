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

    var history: [WalletRemoteHistoryItemProtocol] {
        transfers ?? []
    }
}

extension ReefResponseData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        []
    }
}
