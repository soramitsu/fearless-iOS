import Foundation
import CommonWallet
import BigInt
import IrohaCrypto

extension AssetTransactionData {
    static func createTransaction(from item: SubscanHistoryItemData,
                                  address: String,
                                  networkType: SNAddressType,
                                  asset: WalletAsset,
                                  addressFactory: SS58AddressFactoryProtocol) -> AssetTransactionData {
        let status: AssetTransactionStatus

        if item.finalized == false {
            status = .pending
        } else if let state = item.success {
            status = state ? .commited : .rejected
        } else {
            status = .pending
        }

        let peerAddress = item.sender == address ? item.receiver : item.sender

        let accountId = try? addressFactory.accountId(fromAddress: peerAddress,
                                                      type: networkType)

        let peerId = accountId?.toHex() ?? peerAddress

        let amount = AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0)
        let feeValue = BigUInt(item.fee) ?? BigUInt(0)
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero

        let fee = AssetTransactionFee(identifier: asset.identifier,
                                      assetId: asset.identifier,
                                      amount: AmountDecimal(value: feeDecimal),
                                      context: nil)

        let type = item.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(transactionId: item.hash,
                                    status: status,
                                    assetId: asset.identifier,
                                    peerId: peerId,
                                    peerFirstName: nil,
                                    peerLastName: nil,
                                    peerName: peerAddress,
                                    details: "",
                                    amount: amount,
                                    fees: [fee],
                                    timestamp: item.timestamp,
                                    type: type.rawValue,
                                    reason: nil,
                                    context: nil)
    }

    static func createTransaction(from item: TransactionHistoryItem,
                                  address: String,
                                  networkType: SNAddressType,
                                  asset: WalletAsset,
                                  addressFactory: SS58AddressFactoryProtocol) -> AssetTransactionData {

        let amount = AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0)

        let peerAddress = item.sender == address ? item.receiver : item.sender

        let accountId = try? addressFactory.accountId(fromAddress: peerAddress,
                                                      type: networkType)

        let peerId = accountId?.toHex() ?? peerAddress
        let feeDecimal = Decimal(string: item.fee) ?? .zero

        let fee = AssetTransactionFee(identifier: asset.identifier,
                                      assetId: asset.identifier,
                                      amount: AmountDecimal(value: feeDecimal),
                                      context: nil)

        let type = item.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(transactionId: item.txHash,
                                    status: item.status.walletValue,
                                    assetId: asset.identifier,
                                    peerId: peerId,
                                    peerFirstName: nil,
                                    peerLastName: nil,
                                    peerName: peerAddress,
                                    details: "",
                                    amount: amount,
                                    fees: [fee],
                                    timestamp: item.timestamp,
                                    type: type.rawValue,
                                    reason: nil,
                                    context: nil)
    }
}
