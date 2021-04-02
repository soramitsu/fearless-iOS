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

    func historyIdentifierForAccountId(_ accountId: String, assets _: [String]) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).history"
    }

    func contactsIdentifierForAccountId(_ accountId: String) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).contacts"
    }

    func withdrawMetadataIdentifierForAccountId(
        _ accountId: String,
        assetId _: String,
        optionId _: String
    ) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).withdraw.metadata"
    }

    func transferMetadataIdentifierForAccountId(
        _ accountId: String,
        assetId _: String,
        receiverId _: String
    ) -> String {
        "wallet.cache.\(accountId).\(addressType.rawValue).transfer.metadata"
    }
}
