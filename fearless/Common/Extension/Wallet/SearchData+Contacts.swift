import Foundation
import CommonWallet
import IrohaCrypto

extension SearchData {
    static func createFromContactItem(_ contactItem: ContactItem,
                                      networkType: SNAddressType,
                                      addressFactory: SS58AddressFactory) throws -> SearchData {
        let accountId = try addressFactory.accountId(fromAddress: contactItem.peerAddress,
                                                     type: networkType)

        return SearchData(accountId: accountId.toHex(),
                          firstName: contactItem.peerAddress,
                          lastName: contactItem.peerName ?? "")
    }

    static func createFromAccountItem(_ accountItem: ManagedAccountItem,
                                      addressFactory: SS58AddressFactory) throws -> SearchData {
        let accountId = try addressFactory.accountId(fromAddress: accountItem.address,
                                                     type: accountItem.networkType)

        return SearchData(accountId: accountId.toHex(),
                          firstName: accountItem.address,
                          lastName: accountItem.username)
    }
}
