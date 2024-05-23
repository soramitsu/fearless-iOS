import Foundation
import BigInt

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

struct ReefResponseExtrinsicEdge: Decodable {
    let node: GiantsquidExtrinsic
}

struct ReefResponseTransferEdge: Decodable {
    let node: GiantsquidTransfer
}

struct ReefResponseStakingConnection: Decodable {
    let edges: [ReefResponseStakingEdge]
    let pageInfo: SubqueryPageInfo?
    let totalCount: Int?
}

struct ReefResponseTransfersConnection: Decodable {
    let edges: [ReefResponseTransferEdge]
    let pageInfo: SubqueryPageInfo?
    let totalCount: Int?
}

struct ReefResponseExtrinsicConnection: Decodable {
    let edges: [ReefResponseExtrinsicEdge]
    let pageInfo: SubqueryPageInfo?
    let totalCount: Int?
}

struct ReefResponseData: Decodable {
    let transfersConnection: ReefResponseTransfersConnection?
    let stakingsConnection: ReefResponseStakingConnection?
    let extrinsicsConnection: ReefResponseExtrinsicConnection?

    var history: [WalletRemoteHistoryItemProtocol] {
        let unwrappedTransfers = transfersConnection?.edges.map { $0.node } ?? []
        let unwrappedRewards = stakingsConnection?.edges.map { $0.node } ?? []
        let unwrappedExtrinsics = extrinsicsConnection?.edges.map { $0.node } ?? []

        return unwrappedTransfers + unwrappedRewards + unwrappedExtrinsics
    }
}

extension ReefResponseData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        stakingsConnection?.edges.map { $0.node } ?? []
    }
}

struct ReefSubsquidPageInfo: Decodable {
    let startCursor: String?
    let endCursor: String?
    let hasNextPage: Bool?

    func toContext() -> [String: String]? {
        if startCursor == nil, endCursor == nil {
            return nil
        }
        var context: [String: String] = [:]
        if let startCursor = startCursor {
            context["startCursor"] = startCursor
        }

        if let endCursor = endCursor {
            context["endCursor"] = endCursor
        }

        return context
    }
}
