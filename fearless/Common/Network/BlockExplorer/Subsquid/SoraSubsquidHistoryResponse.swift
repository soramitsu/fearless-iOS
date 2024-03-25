import Foundation
import SSFModels
import CommonWallet
import SSFUtils

struct SoraSubsquidPageInfo: Decodable {
    let endCursor: String?
    let hasNextPage: Bool?
    let hasPreviousPage: Bool?
    let startCursor: String?

    public func toPaginationContext() -> PaginationContext {
        var context = PaginationContext()

        if let startCursor = startCursor {
            context["startCursor"] = startCursor
        }

        if let endCursor = endCursor {
            context["endCursor"] = endCursor
        }

        return context
    }
}

struct SoraSubsquidHistoryElementsConnection: Decodable {
    let edges: [SoraSubsquidHistoryElementNode]
    let pageInfo: SoraSubsquidPageInfo?
    let totalCount: UInt32
}

struct SoraSubsquidHistoryElementNode: Decodable {
    let node: SoraSubsquidHistoryElement
}

struct SoraSubsquidHistoryConnectionResponse: Decodable {
    let historyElementsConnection: SoraSubsquidHistoryElementsConnection
}

struct SoraSubsquidHistoryElement: Decodable {
    let id: String
    let address: String?
    let blockHash: String?
    let blockHeight: UInt64?
    let data: SoraSubsquidHistoryElementData?
    let method: String?
    let name: String?
    let module: String?
    let networkFee: String?
    let timestamp: TimeInterval?
    let execution: SoraSubsquidHistoryElementExecution?
}

struct SoraSubsquidHistoryElementExecution: Decodable {
    let success: Bool?
}

struct SoraSubsquidHistoryElementData: Decodable {
    let era: UInt64?
    let payee: String?
    let stash: String?
    let amount: String?
    let to: String?
    let from: String?
    let assetId: String?
    let targetAssetId: String?
    let baseAssetId: String?
    let baseAssetAmount: String?
    let targetAssetAmount: String?
    let sidechainAddress: String?
    let requestHash: String?

    var anyAssetId: String? {
        targetAssetId ?? baseAssetId ?? assetId
    }
}

extension SoraSubsquidHistoryElement: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 {
        guard let timestamp = timestamp else {
            return 0
        }

        return Int64(timestamp)
    }

    var label: WalletRemoteHistorySourceLabel {
        .extrinsics
    }

    func createTransactionForAddress(
        _ address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            chain: chain,
            asset: asset
        )
    }
}
