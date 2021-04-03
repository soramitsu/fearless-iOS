import Foundation
import CommonWallet
import IrohaCrypto

protocol WalletRemoteHistoryItemProtocol {
    var identifier: String { get }
    var itemBlockNumber: UInt64? { get }
    var itemTimestamp: Int64 { get }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData
}

extension SubscanRewardItemData: WalletRemoteHistoryItemProtocol {
    var identifier: String { "\(recordId)-\(eventIndex)" }
    var itemBlockNumber: UInt64? { blockNumber }
    var itemTimestamp: Int64 { timestamp }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            networkType: networkType,
            asset: asset,
            addressFactory: addressFactory
        )
    }
}

extension SubscanTransferItemData: WalletRemoteHistoryItemProtocol {
    var identifier: String { hash }
    var itemBlockNumber: UInt64? { blockNumber }
    var itemTimestamp: Int64 { timestamp }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            networkType: networkType,
            asset: asset,
            addressFactory: addressFactory
        )
    }
}
