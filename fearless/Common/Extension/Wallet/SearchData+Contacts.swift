import Foundation
import CommonWallet
import IrohaCrypto
import SSFModels

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

    static func createFromContactItem(
        _ contactItem: ContactItem,
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
        guard let chainAccountResponse = account.fetch(for: chain.accountRequest()) else {
            return nil
        }
        let address = try AddressFactory.address(for: chainAccountResponse.accountId, chain: chain)

        let contactContext = ContactContext(destination: .local)

        return SearchData(
            accountId: chainAccountResponse.accountId.toHex(),
            firstName: address,
            lastName: account.name,
            context: contactContext.toContext()
        )
    }
}
