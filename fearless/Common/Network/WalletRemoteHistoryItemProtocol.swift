import Foundation
import CommonWallet
import IrohaCrypto

enum WalletRemoteHistorySourceLabel: Int, CaseIterable {
    case transfers
    case rewards
    case extrinsics
}

protocol WalletRemoteHistoryItemProtocol {
    var identifier: String { get }
    var itemBlockNumber: UInt64 { get }
    var itemExtrinsicIndex: UInt16 { get }
    var itemTimestamp: Int64 { get }
    var label: WalletRemoteHistorySourceLabel { get }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData
}

extension SubscanRewardItemData: WalletRemoteHistoryItemProtocol {
    var identifier: String { "\(recordId)-\(eventIndex)" }
    var itemBlockNumber: UInt64 { blockNumber }
    var itemExtrinsicIndex: UInt16 { extrinsicIndex }
    var itemTimestamp: Int64 { timestamp }
    var label: WalletRemoteHistorySourceLabel { .rewards }

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
    var itemBlockNumber: UInt64 { blockNumber }
    var itemExtrinsicIndex: UInt16 { extrinsicIndex.value }
    var itemTimestamp: Int64 { timestamp }
    var label: WalletRemoteHistorySourceLabel { .transfers }

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

extension SubscanExtrinsicItemData: WalletRemoteHistoryItemProtocol {
    var identifier: String { hash }
    var itemBlockNumber: UInt64 { blockNumber }
    var itemExtrinsicIndex: UInt16 { extrinsicIndex.value }
    var itemTimestamp: Int64 { timestamp }
    var label: WalletRemoteHistorySourceLabel { .extrinsics }

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
