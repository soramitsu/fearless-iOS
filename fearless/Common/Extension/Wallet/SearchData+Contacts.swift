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
        addressPrefix _: UInt16,
        chain: ChainModel
    ) throws -> SearchData {
        let accountId = try AddressFactory.accountId(from: contactItem.peerAddress, chain: chain)

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
        account: MetaAccountModel
    ) throws -> SearchData? {
        guard let accountId = account.fetch(for: chain.accountRequest())?.accountId else {
            assertionFailure()
            return nil
        }
        let address = try AddressFactory.address(for: accountId, chain: chain)

        let contactContext = ContactContext(destination: .local)

        return SearchData(
            accountId: accountId.toHex(),
            firstName: address,
            lastName: account.name,
            context: contactContext.toContext()
        )
    }
}
