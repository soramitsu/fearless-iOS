import Foundation
import CommonWallet
import IrohaCrypto

extension SearchData {
    static func createFromContactItem(
        _ contactItem: ContactItem,
        networkType: SNAddressType,
        addressFactory: SS58AddressFactory
    ) throws -> SearchData {
        let accountId = try addressFactory.accountId(
            fromAddress: contactItem.peerAddress,
            type: networkType
        )

        let contactContext = ContactContext(destination: .remote)

        return SearchData(
            accountId: accountId.toHex(),
            firstName: contactItem.peerAddress,
            lastName: contactItem.peerName ?? "",
            context: contactContext.toContext()
        )
    }

    static func createFromAccountItem(
        _ accountItem: ManagedAccountItem,
        addressFactory: SS58AddressFactory
    ) throws -> SearchData {
        let accountId = try addressFactory.accountId(
            fromAddress: accountItem.address,
            type: accountItem.networkType
        )

        let contactContext = ContactContext(destination: .local)

        return SearchData(
            accountId: accountId.toHex(),
            firstName: accountItem.address,
            lastName: accountItem.username,
            context: contactContext.toContext()
        )
    }

    static func createFromContactItem(
        _ contactItem: ContactItem,
        addressPrefix: UInt16,
        addressFactory: SS58AddressFactory
    ) throws -> SearchData {
        let accountId = try addressFactory.accountId(
            fromAddress: contactItem.peerAddress,
            addressPrefix: addressPrefix
        )

        let contactContext = ContactContext(destination: .remote)

        return SearchData(
            accountId: accountId.toHex(),
            firstName: contactItem.peerAddress,
            lastName: contactItem.peerName ?? "",
            context: contactContext.toContext()
        )
    }

    static func createFromChainAccount(
        chain: ChainModel,
        account: MetaAccountModel,
        addressFactory: SS58AddressFactory
    ) throws -> SearchData? {
        guard let accountId = account.fetch(for: chain.accountRequest())?.accountId else {
            return nil
        }

        let address = try addressFactory.address(fromAccountId: accountId, type: chain.addressPrefix)

        let contactContext = ContactContext(destination: .local)

        return SearchData(
            accountId: accountId.toHex(),
            firstName: address,
            lastName: account.name,
            context: contactContext.toContext()
        )
    }
}
