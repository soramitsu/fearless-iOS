import Foundation
import CommonWallet
import IrohaCrypto
import RobinHood

enum WalletRemoteHistorySourceLabel: Int, CaseIterable {
    case transfers
    case rewards
    case extrinsics
}

protocol WalletRemoteHistoryItemProtocol {
    var identifier: String { get }
    var itemBlockNumber: UInt64 { get }
    var itemExtrinsicIndex: UInt16 { get }
    var extrinsicHash: String? { get }
    var itemTimestamp: Int64 { get }
    var label: WalletRemoteHistorySourceLabel { get }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData
}

struct WalletRemoteHistoryData {
    let historyItems: [WalletRemoteHistoryItemProtocol]
    let context: TransactionHistoryContext
}

protocol WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(for context: TransactionHistoryContext, address: String, count: Int)
        -> CompoundOperationWrapper<WalletRemoteHistoryData>
}
