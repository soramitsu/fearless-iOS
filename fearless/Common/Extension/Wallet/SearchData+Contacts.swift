import Foundation
import CommonWallet
import IrohaCrypto

extension SearchData {
    static func createFromContactItem(_ contactItem: ContactItem,
                                      networkType: SNAddressType,
                                      addressFactory: SS58AddressFactory) throws -> SearchData {
        let accountId = try addressFactory.accountId(fromAddress: contactItem.peerAddress,
                                                     type: networkType)

        let contactContext = ContactContext(destination: .remote)

        return SearchData(accountId: accountId.toHex(),
                          firstName: contactItem.peerAddress,
                          lastName: contactItem.peerName ?? "",
                          context: contactContext.toContext())
    }

    static func createFromAccountItem(_ accountItem: ManagedAccountItem,
                                      addressFactory: SS58AddressFactory) throws -> SearchData {
        let accountId = try addressFactory.accountId(fromAddress: accountItem.address,
                                                     type: accountItem.networkType)

        let contactContext = ContactContext(destination: .local)

        return SearchData(accountId: accountId.toHex(),
                          firstName: accountItem.address,
                          lastName: accountItem.username,
                          context: contactContext.toContext())
    }
}
