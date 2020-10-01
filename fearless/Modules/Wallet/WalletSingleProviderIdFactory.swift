import Foundation
import CommonWallet
import IrohaCrypto

final class WalletSingleProviderIdFactory: SingleProviderIdentifierFactoryProtocol {
    let addressType: SNAddressType

    init(addressType: SNAddressType) {
        self.addressType = addressType
    }

    func balanceIdentifierForAccountId(_ accountId: String) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).balance"
    }

    func historyIdentifierForAccountId(_ accountId: String, assets: [String]) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).history"
    }

    func contactsIdentifierForAccountId(_ accountId: String) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).contacts"
    }

    func withdrawMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                optionId: String) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).withdraw.metadata"
    }

    func transferMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                receiverId: String) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).transfer.metadata"
    }
}
